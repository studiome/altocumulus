require "test_helper"

class HolidayTest < ActiveSupport::TestCase
  test "should be valid" do
    holiday = Holiday.new(date: Date.new(2026, 5, 4), name: "Greenery Day")
    assert holiday.valid?
  end

  test "should require date" do
    holiday = Holiday.new(name: "No date")
    assert_not holiday.valid?
    assert_includes holiday.errors[:date], "can't be blank"
  end

  test "should require name" do
    holiday = Holiday.new(date: Date.new(2026, 5, 5))
    assert_not holiday.valid?
    assert_includes holiday.errors[:name], "can't be blank"
  end

  test "should reject a duplicate date" do
    holiday = Holiday.new(date: holidays(:national_holiday).date, name: "Duplicate")
    assert_not holiday.valid?
    assert_includes holiday.errors[:date], "has already been taken"
  end

  test "ordered sorts by date" do
    assert_equal [ holidays(:national_holiday), holidays(:year_end) ], Holiday.ordered.to_a
  end

  test "between filters to the given date range" do
    result = Holiday.between(Date.new(2026, 3, 1), Date.new(2026, 3, 31))
    assert_equal [ holidays(:national_holiday) ], result.to_a
  end

  test "by_date indexes holidays by date for the given dates, including ones with no holiday" do
    dates = [ holidays(:national_holiday).date, Date.new(2026, 3, 11) ]
    index = Holiday.by_date(dates)

    assert_equal holidays(:national_holiday), index[holidays(:national_holiday).date]
    assert_nil index[Date.new(2026, 3, 11)]
  end

  test "filtered with no year returns all holidays" do
    assert_equal Holiday.count, Holiday.filtered.count
  end

  test "filtered by year returns only holidays in that year" do
    result = Holiday.filtered(year: 2026).order(:date)
    assert_equal [ holidays(:national_holiday), holidays(:year_end) ], result.to_a
  end

  test "filtered by a year with no holidays returns none" do
    assert_empty Holiday.filtered(year: 1999)
  end

  test "available_years returns registered years in descending order" do
    assert_equal [ 2026 ], Holiday.available_years
  end

  test "to_s renders the date and name" do
    holiday = holidays(:national_holiday)
    assert_equal "2026-03-10 Vernal Equinox Day", holiday.to_s
  end
end
