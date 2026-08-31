require "test_helper"

class FilterBarLayoutTest < ActionDispatch::IntegrationTest
  # daisyUI 5 dropped these; they compile to nothing, so a wrapper that relies
  # on them for stacking a label above its input silently loses its layout.
  REMOVED_DAISYUI_V4_CLASSES = %w[form-control label-text].freeze

  # Every page that renders a filter form.
  FILTERED_PAGES = %w[/surgeries /hospitalizations /patients /dashboard].freeze

  # The dashboard year picker sits inline in the page header, so it is not a bar.
  FILTER_BAR_PAGES = %w[/surgeries /hospitalizations /patients].freeze

  test "filter forms avoid daisyUI 4 classes that version 5 removed" do
    FILTERED_PAGES.each do |path|
      get path

      REMOVED_DAISYUI_V4_CLASSES.each do |klass|
        assert_no_match(/class="[^"]*\b#{klass}\b/, response.body,
                        "#{path} still uses the removed daisyUI class #{klass.inspect}")
      end
    end
  end

  test "filter forms lay their fields out in a row" do
    FILTER_BAR_PAGES.each do |path|
      get path

      assert_select "form.app-filter-bar", 1, "#{path} should render its filters as a filter bar"
      # .app-panel is .card, which pins flex-direction: column and would stack
      # every filter into a tall right-aligned column.
      assert_select "form.app-panel", false, "#{path} filter form must not be a card"
    end
  end
end
