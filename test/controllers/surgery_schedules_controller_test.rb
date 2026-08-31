require "test_helper"

class SurgerySchedulesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get surgery_schedule_url
    assert_response :success
  end

  test "index defaults to the week containing today" do
    travel_to Date.new(2026, 3, 4) do # Wednesday
      get surgery_schedule_url
      assert_response :success
      assert_match(/2026-03-02/, @response.body) # Monday of that week
      assert_match(/2026-03-08/, @response.body) # Sunday of that week
    end
  end

  test "index accepts a week_of param and shows that week's Monday through Sunday" do
    get surgery_schedule_url, params: { week_of: "2026-03-03" } # a Tuesday
    assert_response :success
    assert_match(/2026-03-02/, @response.body)
    assert_match(/2026-03-08/, @response.body)
  end

  test "index links to the previous and next week" do
    get surgery_schedule_url, params: { week_of: "2026-03-03" }
    assert_response :success
    assert_select "a[href*='week_of=2026-02-23']"
    assert_select "a[href*='week_of=2026-03-09']"
  end

  test "index shows open and filled elective slots and an over capacity section" do
    get surgery_schedule_url, params: { week_of: "2026-03-03" } # week of Mon 2026-03-02 .. Sun 2026-03-08
    assert_response :success
    assert_match(/Open/, @response.body)
    assert_match(/Over capacity/, @response.body)
    assert_match(/Emergency/, @response.body)
  end

  test "index shows the emergency section, its start time, and unconfigured-day warnings for a week containing 2026-03-01" do
    get surgery_schedule_url, params: { week_of: "2026-02-25" } # week of Mon 2026-02-23 .. Sun 2026-03-01
    assert_response :success
    assert_match(/23:30/, @response.body)
    assert_match(/No elective slots are configured for Sunday/, @response.body)
  end
end
