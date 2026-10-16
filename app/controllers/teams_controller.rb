# Teams are an ordinary master (name / position / active) plus a color; their
# terms and members live under /teams/:id/team_terms (TeamTermsController).
class TeamsController < MasterRecordsController
  include RequiresTeamsFeature

  private

    def master_class = Team
end
