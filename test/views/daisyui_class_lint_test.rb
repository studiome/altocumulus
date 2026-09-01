require "test_helper"

# daisyUI 5 dropped or renamed a number of version 4 class names. They compile
# to nothing, so a view that still uses one silently loses that styling with no
# error anywhere. Catch them at the source instead.
class DaisyuiClassLintTest < ActiveSupport::TestCase
  REMOVED_IN_DAISYUI_5 = {
    "form-control" => "wrap the field in .app-filter-field / .app-field instead",
    "label-text" => "the surrounding .label already styles its text",
    "input-bordered" => ".input is bordered by default in daisyUI 5",
    "select-bordered" => ".select is bordered by default in daisyUI 5",
    "textarea-bordered" => ".textarea is bordered by default in daisyUI 5",
    "hover" => "table row hover is .row-hover in daisyUI 5"
  }.freeze

  CLASS_ATTRIBUTE = /class(?:=|:\s*)"([^"]*)"/
  # Variants and arbitrary values are part of the token, so that a legitimate
  # "hover:opacity-80" is never mistaken for a bare "hover".
  CLASS_TOKEN = %r{[A-Za-z][A-Za-z0-9:_./\[\]%-]*}

  test "views do not use daisyUI 4 class names that version 5 removed" do
    offenses = []

    Dir.glob(Rails.root.join("app/views/**/*.erb")).sort.each do |path|
      File.readlines(path).each_with_index do |line, index|
        line.scan(CLASS_ATTRIBUTE).flatten.each do |attribute|
          attribute.scan(CLASS_TOKEN).each do |token|
            next unless REMOVED_IN_DAISYUI_5.key?(token)

            offenses << "#{path.delete_prefix("#{Rails.root}/")}:#{index + 1} " \
                        "uses #{token.inspect} (#{REMOVED_IN_DAISYUI_5[token]})"
          end
        end
      end
    end

    assert_empty offenses, "Removed daisyUI 4 classes still in use:\n#{offenses.join("\n")}"
  end

  test "daisyUI calendar component is excluded because the app does not use it" do
    tailwind_source = Rails.root.join("app/assets/tailwind/application.css").read

    assert_match(/exclude:\s*calendar\s*;/, tailwind_source)
  end
end
