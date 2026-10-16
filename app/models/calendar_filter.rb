# The filters of the operations calendar's two tabs: "only cases I am involved
# in" (mine) and, with features.teams, one team. Carried in GET params so they
# survive tab switches and range changes.
#
# A case is "mine" when the user is its reservation doctor or the person who
# entered the reservation, is named in the surgery's operator name, or is a
# member of the case's team term on the case date. Everything is matched in
# SQL (one query per tab), so the calendars stay bounded however many cases the
# range holds.
class CalendarFilter
  attr_reader :user, :team_id

  # The team_id param value for "team undecided" (the same word the team
  # select submits, see TeamAssignable).
  UNDECIDED = TeamAssignable::UNDECIDED

  # Surgery rows are joined to their hospitalization (LEFT JOIN, may be absent).
  # A surgery left undecided on its own has no effective team, whatever its
  # hospitalization says.
  SURGERY_TEAM = "(CASE WHEN surgeries.team_undecided THEN NULL ELSE COALESCE(surgeries.team_id, hospitalizations.team_id) END)".freeze
  SURGERY_TEAM_UNDECIDED = "(#{SURGERY_TEAM} IS NULL AND (surgeries.team_undecided OR hospitalizations.team_undecided))".freeze
  HOSPITALIZATION_DATE = "COALESCE(hospitalizations.scheduled_procedure_date, hospitalizations.admission_date, hospitalizations.scheduled_admission_date)".freeze

  SURGERY_TEAM_MEMBER = <<~SQL.squish.freeze
    EXISTS (SELECT 1 FROM team_term_members ttm INNER JOIN team_terms tt ON tt.id = ttm.team_term_id
            WHERE ttm.user_id = :user_id AND tt.team_id = #{SURGERY_TEAM}
              AND tt.starts_on <= surgeries.surgery_date AND tt.ends_on >= surgeries.surgery_date)
  SQL

  HOSPITALIZATION_TEAM_MEMBER = <<~SQL.squish.freeze
    EXISTS (SELECT 1 FROM team_term_members ttm INNER JOIN team_terms tt ON tt.id = ttm.team_term_id
            WHERE ttm.user_id = :user_id AND tt.team_id = hospitalizations.team_id
              AND tt.starts_on <= COALESCE(hospitalizations.scheduled_procedure_date, hospitalizations.admission_date, hospitalizations.scheduled_admission_date)
              AND tt.ends_on >= COALESCE(hospitalizations.scheduled_procedure_date, hospitalizations.admission_date, hospitalizations.scheduled_admission_date))
  SQL

  def self.none
    new(user: nil)
  end

  # Reads `mine` ("1") and `team_id` (digits, or "undecided") from request
  # params; anything else is ignored, and the team filter only exists with
  # features.teams.
  def self.from_params(params, user:)
    mine = params[:mine].to_s == "1"
    raw = params[:team_id].to_s
    teams = SiteConfig.current.teams_enabled?
    team_id = raw.match?(/\A\d+\z/) && teams ? raw.to_i : nil
    new(user: user, mine: mine, team_id: team_id, team_undecided: teams && raw == UNDECIDED)
  end

  def initialize(user:, mine: false, team_id: nil, team_undecided: false)
    @user = user
    @mine = mine && user.present?
    @team_id = team_id
    @team_undecided = team_undecided && team_id.nil?
  end

  def team_undecided?
    @team_undecided
  end

  def mine?
    @mine
  end

  def active?
    mine? || team_id.present? || team_undecided?
  end

  # Query-string params that reproduce this filter (for links and forms).
  def to_params
    { mine: ("1" if mine?), team_id: (UNDECIDED if team_undecided?) || team_id }.compact
  end

  # ids of the surgeries on `dates` that pass the filter, or nil when the
  # filter is not active (nil = show everything).
  def surgery_ids(dates)
    return nil unless active?

    scope = Surgery.where(surgery_date: dates).left_joins(:hospitalization)
    scope = scope.where(surgery_mine_sql, **mine_binds) if mine?
    scope = scope.where("#{SURGERY_TEAM} = ?", team_id) if team_id
    scope = scope.where(SURGERY_TEAM_UNDECIDED) if team_undecided?
    scope.pluck(:id).to_set
  end

  # `scope` (hospitalizations, with the table unaliased) narrowed by the filter.
  def apply_to_hospitalizations(scope)
    scope = scope.where(hospitalization_mine_sql, **mine_binds) if mine?
    scope = scope.where(team_id: team_id) if team_id
    scope = scope.where(team_undecided: true) if team_undecided?
    scope
  end

  private

    def mine_binds
      { user_id: user.id, pattern: "%#{ActiveRecord::Base.sanitize_sql_like(user.name.to_s)}%", has_name: user.name.present? }
    end

    def surgery_mine_sql
      parts = [ "hospitalizations.reservation_doctor_id = :user_id", "hospitalizations.created_by_id = :user_id",
                "(:has_name AND surgeries.operator_name LIKE :pattern ESCAPE '\\')" ]
      parts << SURGERY_TEAM_MEMBER if SiteConfig.current.teams_enabled?
      parts.join(" OR ")
    end

    def hospitalization_mine_sql
      parts = [ "hospitalizations.reservation_doctor_id = :user_id", "hospitalizations.created_by_id = :user_id" ]
      parts << HOSPITALIZATION_TEAM_MEMBER if SiteConfig.current.teams_enabled?
      parts.join(" OR ")
    end
end
