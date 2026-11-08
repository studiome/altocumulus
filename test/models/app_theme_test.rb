require "test_helper"

# The palettes live in app/assets/tailwind/application.css. This test parses
# that file, so a new preset without light and dark blocks, or with unreadable
# colour pairs, fails here instead of in somebody's browser.
class AppThemeTest < ActiveSupport::TestCase
  CSS = File.read(Rails.root.join("app/assets/tailwind/application.css"))

  PAIRS = [
    [ "--app-bar-fg", "--app-bar-bg" ],
    [ "--color-primary-content", "--color-primary" ],
    [ "--color-secondary-content", "--color-secondary" ],
    [ "--app-link", "--color-base-100" ],
    [ "--color-base-content", "--ledger-head" ]
  ].freeze

  def self.vars(body)
    body.scan(/(--[\w-]+):\s*(#[0-9a-fA-F]{3,6})\s*;/).to_h
  end

  def self.block(selector, dark:)
    pattern = Regexp.new(Regexp.escape(selector) + '\s*\{([^}]*)\}')
    media = /@media \(prefers-color-scheme: dark\) \{\n(.*?)\n\}\n/m
    source = dark ? CSS.scan(media).flatten.join("\n") : CSS.gsub(media, "")
    match = source.match(pattern)
    match && vars(match[1])
  end

  def self.palette(key, dark:)
    base = block(dark ? ":root:not([data-theme])" : ":root", dark: dark)
    return base if key == "navy"
    own = block(dark ? %(:root[data-app-theme="#{key}"]:not([data-theme])) : %(:root[data-app-theme="#{key}"]), dark: dark)
    own && base.merge(own)
  end

  def luminance(hex)
    hex = hex.delete("#")
    hex = hex.chars.map { |c| c * 2 }.join if hex.size == 3
    r, g, b = hex.scan(/../).map { |c| c.to_i(16) / 255.0 }.map { |c| c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4 }
    0.2126 * r + 0.7152 * g + 0.0722 * b
  end

  def contrast(a, b)
    hi, lo = [ luminance(a), luminance(b) ].max, [ luminance(a), luminance(b) ].min
    (hi + 0.05) / (lo + 0.05)
  end

  test "the default is navy and the keys are a small fixed set" do
    assert_equal "navy", AppTheme::DEFAULT
    assert_includes AppTheme::KEYS, "navy"
    assert_includes 4..6, AppTheme::KEYS.size
  end

  test "every theme has a label in both locales" do
    %i[en ja].each do |locale|
      AppTheme::KEYS.each do |key|
        assert I18n.exists?("app_themes.#{key}", locale), "missing #{locale} label for #{key}"
      end
    end
  end

  test "every non-default theme has a light block and a dark block" do
    (AppTheme::KEYS - [ "navy" ]).each do |key|
      assert self.class.block(%(:root[data-app-theme="#{key}"]), dark: false), "#{key} light block missing"
      assert self.class.block(%(:root[data-app-theme="#{key}"]:not([data-theme])), dark: true), "#{key} dark block missing"
    end
  end

  test "text and background pairs are readable in every theme and mode" do
    AppTheme::KEYS.each do |key|
      [ false, true ].each do |dark|
        palette = self.class.palette(key, dark: dark)
        mode = dark ? "dark" : "light"
        assert palette, "#{key} #{mode} palette missing"
        PAIRS.each do |fg, bg|
          ratio = contrast(palette.fetch(fg), palette.fetch(bg))
          assert_operator ratio, :>=, 4.5, "#{key} #{mode}: #{fg} on #{bg} is #{ratio.round(2)}"
        end
      end
    end
  end

  test "theme_color is the light app bar colour of each theme" do
    AppTheme::KEYS.each do |key|
      assert_equal self.class.palette(key, dark: false).fetch("--app-bar-bg").downcase, AppTheme.theme_color(key).downcase
    end
  end

  test "theme_color falls back to the default for an unknown key" do
    assert_equal AppTheme.theme_color("navy"), AppTheme.theme_color("nope")
  end
end
