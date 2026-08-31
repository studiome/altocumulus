require "test_helper"

class HolidaysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @holiday = holidays(:national_holiday)
  end

  test "should get index" do
    get holidays_url
    assert_response :success
  end

  test "index lists holidays" do
    get holidays_url
    assert_response :success
    assert_match(/Vernal Equinox Day/, @response.body)
    assert_match(/Year-end closure/, @response.body)
  end

  test "index filters by year" do
    get holidays_url, params: { year: 2026 }
    assert_response :success
    assert_match(/Vernal Equinox Day/, @response.body)
  end

  test "index filters out years with no holidays" do
    get holidays_url, params: { year: 1999 }
    assert_response :success
    assert_no_match(/Vernal Equinox Day/, @response.body)
  end

  test "index paginates" do
    get holidays_url, params: { page: 1 }
    assert_response :success
  end

  test "should get new" do
    get new_holiday_url
    assert_response :success
  end

  test "should create holiday" do
    assert_difference("Holiday.count") do
      post holidays_url, params: { holiday: { date: "2026-11-03", name: "Culture Day" } }
    end

    assert_redirected_to holiday_url(Holiday.last)
  end

  test "should reject a duplicate date" do
    assert_no_difference("Holiday.count") do
      post holidays_url, params: { holiday: { date: @holiday.date, name: "Duplicate" } }
    end

    assert_response :unprocessable_entity
  end

  test "should show holiday" do
    get holiday_url(@holiday)
    assert_response :success
  end

  test "should get edit" do
    get edit_holiday_url(@holiday)
    assert_response :success
  end

  test "should update holiday" do
    patch holiday_url(@holiday), params: { holiday: { name: "Renamed Holiday" } }

    assert_redirected_to holiday_url(@holiday)
    @holiday.reload
    assert_equal "Renamed Holiday", @holiday.name
  end

  test "should destroy holiday" do
    assert_difference("Holiday.count", -1) do
      delete holiday_url(@holiday)
    end

    assert_redirected_to holidays_url
  end
end
