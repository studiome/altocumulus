require "test_helper"

class DashboardHelperTest < ActionView::TestCase
  include DashboardHelper

  test "labels months with the month name alone when the window stays in one year" do
    months = (1..12).map { |month| Date.new(2026, month, 1) }

    assert_equal "Jan", monthly_axis_label(months.first, months)
    assert_equal "Dec", monthly_axis_label(months.last, months)
  end

  test "labels months with the year when the window spans more than one year" do
    months = 11.downto(0).map { |offset| Date.new(2026, 8, 1) - offset.months }

    assert_equal "Sep '25", monthly_axis_label(months.first, months)
    assert_equal "Aug '26", monthly_axis_label(months.last, months)
  end
end
