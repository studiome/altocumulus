require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Altocumulus
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Tokyo"
    # A `time` column (Surgery#start_time) is a wall-clock time of day with no
    # date attached, so it must not be shifted between zones: converting it
    # would reinterpret every already-stored value by the UTC offset. Only
    # `datetime` columns are time-zone aware.
    config.active_record.time_zone_aware_types = [ :datetime ]
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
