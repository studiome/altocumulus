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

  # Surgery rows are joined to their hospitalization (LEFT JOIN, may be absent).
  SURGERY_TEAM = "COALESCE(surgeries.team_id, hospitalizations.team_id)".freeze
  HOSPITALIZATION_DATE = "COALESCE(hospitalizations.scheduled_procedure_date, hospitalizations.admission_date, hospitalizations.scheduled_admission_date)".freeze

  SURGERY_TEAM_MEMBER = <<~SQL.squish.freeze
    EXISTS (SELECT 1 FROM team_term_members ttm INNER JOIN team_terms tt ON tt.id = ttm.team_term_id
            WHERE ttm.user_id = :user_id AND tt.team_id = COALESCE(surgeries.team_id, hospitalizations.team_id)
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

  # Reads `mine` ("1") and `team_id` (digits) from request params; anything
  # else is ignored, and the team filter only exists with features.teams.
  def self.from_params(params, user:)
    mine = params[:mine].to_s == "1"
    team_id = params[:team_id].to_s.match?(/\A\d+\z/) && SiteConfig.current.teams_enabled? ? params[:team_id].to_i : nil
    new(user: user, mine: mine, team_id: team_id)
  end

  def initialize(user:, mine: false, team_id: nil)
    @user = user
    @mine = mine && user.present?
    @team_id = team_id
  end

  def mine?
    @mine
  end

  def active?
    mine? || team_id.present?
  end

  # Query-string params that reproduce this filter (for links and forms).
  def to_params
    { mine: ("1" if mine?), team_id: team_id }.compact
  end

  # ids of the surgeries on `dates` that pass the filter, or nil when the
  # filter is not active (nil = show everything).
  def surgery_ids(dates)
    return nil unless active?

    scope = Surgery.where(surgery_date: dates).left_joins(:hospitalization)
    scope = scope.where(surgery_mine_sql, **mine_binds) if mine?
    scope = scope.where("#{SURGERY_TEAM} = ?", team_id) if team_id
    scope.pluck(:id).to_set
  end

  # `scope` (hospitalizations, with the table unaliased) narrowed by the filter.
  def apply_to_hospitalizations(scope)
    scope = scope.where(hospitalization_mine_sql, **mine_binds) if mine?
    scope = scope.where(team_id: team_id) if team_id
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
