# Hides the team screens (as a plain 404) while the site config has
# features.teams off.
module RequiresTeamsFeature
  extend ActiveSupport::Concern

  included do
    before_action :require_teams_feature
  end

  private

    def require_teams_feature
      head :not_found unless SiteConfig.current.teams_enabled?
    end
end
