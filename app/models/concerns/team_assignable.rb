# Team assignment shared by Hospitalization and Surgery: an optional team, and
# the members of the term that covers the case's date. The including model
# supplies `team_display_date` (which of its dates decides the term) and may
# override `effective_team` (a surgery falls back to its hospitalization's).
module TeamAssignable
  extend ActiveSupport::Concern

  included do
    belongs_to :team, optional: true
  end

  def effective_team
    team
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
