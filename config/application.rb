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

    # This app supports Japanese and English UI, with English as the
    # default (matches Rails' own default, but stated explicitly so the
    # intent is clear). A user's preferred locale is a separate concern
    # from the app's time zone above: config.time_zone controls how
    # datetime columns are interpreted/displayed, not which language
    # strings render in.
    config.i18n.available_locales = [ :en, :ja ]
    config.i18n.default_locale = :en
    # Fall back to the default locale (English) instead of raising when a
    # translation is missing in the current locale, e.g. while ja.yml is
    # still being filled in incrementally across the i18n rollout.
    config.i18n.fallbacks = true
    # A `time` column (Surgery#start_time) is a wall-clock time of day with no
    # date attached, so it must not be shifted between zones: converting it
    # would reinterpret every already-stored value by the UTC offset. Only
    # `datetime` columns are time-zone aware.
    config.active_record.time_zone_aware_types = [ :datetime ]
    # config.eager_load_paths << Rails.root.join("extras")

    # How long a signed-in session may go without activity before it is
    # invalidated. Overridable per-environment via ENV so ops can tighten or
    # relax this without a code change.
    config.x.session_idle_timeout = (ENV["SESSION_IDLE_TIMEOUT_MINUTES"].presence || 10).to_i.minutes

    # The operations calendar flags a day whose admission count exceeds this
    # as a "congestion" warning. Display-only: it never blocks a save (see
    # OperationsCalendar). Overridable per-environment via ENV.
    config.x.admission_warning_threshold = (ENV["ADMISSION_WARNING_THRESHOLD"].presence || 5).to_i

    # This app does not use Active Storage attachments/variants anywhere
    # (no has_one_attached/has_many_attached, no active_storage tables in
    # db/schema.rb). Active Storage still eagerly requires an image variant
    # transformer at boot, and as of image_processing 2.x that gem no longer
    # pulls in ruby-vips as a dependency, so requiring it raises a LoadError
    # that Rails' active_storage engine only rescues for a couple of specific
    # message patterns. Disabling the variant processor entirely selects
    # Active Storage's NullTransformer, which skips that require altogether.
    # If this app starts handling attachments, add `image_processing` (already
    # in the Gemfile) and `ruby-vips` as real dependencies, add libvips
    # installation to .github/workflows/ci.yml, and remove this line.
    config.active_storage.variant_processor = :disabled
  end
end
