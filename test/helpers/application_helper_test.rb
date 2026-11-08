require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "tab_bar_class is a large boxed tab bar that hides in print by default" do
    classes = tab_bar_class.split
    %w[tabs tabs-box tabs-lg].each { |c| assert_includes classes, c }
    assert_includes classes, "print:hidden"
  end

  test "tab_bar_class keeps the bar in print when hide_in_print is false" do
    assert_not_includes tab_bar_class(hide_in_print: false).split, "print:hidden"
    assert_includes tab_bar_class(hide_in_print: false).split, "tabs"
  end

  test "tab_link_class fills the selected tab and hovers the others" do
    selected = tab_link_class(true).split
    assert_includes selected, "tab"
    assert_includes selected, "tab-active"
    assert_includes selected, "bg-primary"
    unselected = tab_link_class(false).split
    assert_includes unselected, "tab"
    assert_not_includes unselected, "tab-active"
    assert_includes unselected, "hover:bg-base-300"
  end

  test "date_with_weekday shows the abbreviated weekday in English" do
    I18n.with_locale(:en) do
      assert_includes date_with_weekday(Date.new(2026, 10, 5)), "2026-10-05 (Mon)"
    end
  end

  test "date_with_weekday shows the abbreviated weekday in Japanese" do
    I18n.with_locale(:ja) do
      assert_includes date_with_weekday(Date.new(2026, 10, 5)), "2026/10/05（月）"
    end
  end

  test "date_with_weekday leaves weekdays uncoloured" do
    html = date_with_weekday(Date.new(2026, 10, 5))

    assert_no_match(/app-date-(sat|holiday)/, html)
  end

  test "date_with_weekday marks Saturday as blue" do
    assert_match(/class="[^"]*app-date-sat/, date_with_weekday(Date.new(2026, 10, 3)))
  end

  test "date_with_weekday marks Sunday as holiday red" do
    assert_match(/class="[^"]*app-date-holiday/, date_with_weekday(Date.new(2026, 10, 4)))
  end

  test "date_with_weekday marks a closed holiday on a weekday as red" do
    assert_match(/class="[^"]*app-date-holiday/, date_with_weekday(Date.new(2026, 3, 10)))
  end

  test "date_with_weekday ignores a non-holiday note row" do
    Holiday.create!(date: Date.new(2026, 10, 6), holiday: false, note: "Staff meeting")

    assert_no_match(/app-date-holiday/, date_with_weekday(Date.new(2026, 10, 6)))
  end

  test "date_with_weekday uses the preloaded holidays instead of querying" do
    holidays = Holiday.by_date([ Date.new(2026, 3, 10) ])

    assert_no_queries do
      assert_match(/app-date-holiday/, date_with_weekday(Date.new(2026, 3, 10), holidays: holidays))
    end
  end

  test "date_with_weekday colours a closed holiday that falls on Saturday as holiday" do
    Holiday.create!(date: Date.new(2026, 10, 10), name: "Closure")

    html = date_with_weekday(Date.new(2026, 10, 10))

    assert_match(/app-date-holiday/, html)
    assert_no_match(/app-date-sat/, html)
  end

  private

    def assert_no_queries(&block)
      count = 0
      counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
      assert_equal 0, count
    end
end
