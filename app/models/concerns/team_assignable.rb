# Team assignment shared by Hospitalization and Surgery: an optional team, and
# the members of the term that covers the case's date. The including model
# supplies `team_display_date` (which of its dates decides the term) and may
# override `effective_team` (a surgery falls back to its hospitalization's).
#
# "Team undecided" (チーム未決定) is a deliberate answer, kept apart from a blank
# team ("not chosen yet"): `team_undecided` is true and `team_id` nil. Forms
# submit it as the select value `team_id=undecided`, which `team_id=` turns
# into the flag, so no fake Team row is needed.
module TeamAssignable
  extend ActiveSupport::Concern

  UNDECIDED = "undecided".freeze

  included do
    belongs_to :team, optional: true
    # A team and "undecided" are exclusive; a chosen team wins.
    before_validation { self.team_undecided = false if team_id.present? }
  end

  def team_id=(value)
    if value.to_s == UNDECIDED
      self.team_undecided = true
      super(nil)
    else
      self.team_undecided = false
      super
    end
  end

  # The value the team select shows: a team id, UNDECIDED, or nil (not chosen).
  def team_choice
    team_undecided? ? UNDECIDED : team_id
  end

  def effective_team
    team
  end

  # True when the case has no team and its team was explicitly left undecided.
  def effective_team_undecided?
    effective_team.nil? && team_undecided?
  end

  # The term of the effective team covering the case date; nil when there is
  # no team, the case is undated, or no term covers the date.
  def team_term
    date = team_display_date
    effective_team&.term_for(date) if date
  end

  # The members line, or nil when there is nothing to show (no team, undated,
  # no term, a term without members).
  def team_members_display
    team_term&.members_display.presence
  end
end
