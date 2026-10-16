# Load (and validate) the deploy-time site configuration once everything,
# including the models whose attribute names it is checked against, can be
# autoloaded. A bad file raises SiteConfig::Error here, failing the boot.
Rails.application.config.after_initialize do
  SiteConfig.reset!
  SiteConfig.current
end
