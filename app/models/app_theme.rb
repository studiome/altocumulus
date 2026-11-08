# The fixed set of colour palettes an administrator can choose for the whole
# installation (AppSetting#theme). Only the keys and the browser-chrome colour
# live here; the palettes themselves are CSS variables in
# app/assets/tailwind/application.css, selected by the data-app-theme
# attribute on <html>. navy is the plain :root look; every other key needs a
# light and a dark block there (test/models/app_theme_test.rb checks both,
# including text contrast).
module AppTheme
  KEYS = %w[navy green maroon teal gray].freeze
  DEFAULT = "navy"

  # The light-mode navbar colour: used for <meta name="theme-color"> and the
  # PWA manifest. Keep equal to the theme's --app-bar-bg.
  THEME_COLORS = {
    "navy" => "#000080",
    "green" => "#1f5c3f",
    "maroon" => "#7a1f2b",
    "teal" => "#0f5c66",
    "gray" => "#3f4650"
  }.freeze

  def self.theme_color(key)
    THEME_COLORS.fetch(key.to_s) { THEME_COLORS.fetch(DEFAULT) }
  end

  # Palette keys with the two colours a swatch shows (navbar, primary).
  def self.swatch(key)
    { bar: theme_color(key), primary: THEME_SWATCH_PRIMARY.fetch(key) }
  end

  THEME_SWATCH_PRIMARY = {
    "navy" => "#3a55c8",
    "green" => "#2f7d58",
    "maroon" => "#a8404f",
    "teal" => "#1f7f89",
    "gray" => "#5d6672"
  }.freeze
end
