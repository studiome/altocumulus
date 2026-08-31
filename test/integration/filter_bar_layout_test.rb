require "test_helper"

class FilterBarLayoutTest < ActionDispatch::IntegrationTest
  # The dashboard year picker sits inline in the page header, so it is not a bar.
  FILTER_BAR_PAGES = %w[/surgeries /hospitalizations /patients].freeze

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
