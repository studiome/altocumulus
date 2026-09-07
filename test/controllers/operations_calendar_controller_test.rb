require "test_helper"

class OperationsCalendarControllerTest < ActionDispatch::IntegrationTest
  test "shows exactly 50 days by default, not 51" do
    get operations_calendar_url
    assert_response :success
    assert_select ".oc-day", 50
  end

  test "an invalid start date redirects with guidance instead of raising" do
    get operations_calendar_url, params: { start: "not-a-date" }
    assert_redirected_to operations_calendar_url
    follow_redirect!
    assert_response :success
  end

  test "a days value beyond the maximum redirects with guidance instead of raising" do
    get operations_calendar_url, params: { days: OperationsCalendar::MAX_DAYS + 1 }
    assert_redirected_to operations_calendar_url
  end

  test "a crafted Array days param does not error out" do
    get operations_calendar_url, params: { days: [ "1" ] }
    assert_redirected_to operations_calendar_url
  end

  test "a crafted Array start param does not error out" do
    get operations_calendar_url, params: { start: [ "2026-01-01" ] }
    assert_response :success
  end

  test "an explicit valid start and days renders that range" do
    get operations_calendar_url, params: { start: "2026-01-01", days: 10 }
    assert_response :success
    assert_select ".oc-day", 10
  end

  test "shows a published announcement but not a draft one" do
    get operations_calendar_url
    assert_response :success
    assert_match(/Winter schedule notice/, @response.body)
    assert_no_match(/Draft: new ward opening/, @response.body)
  end

  test "each day links to a new hospitalization pre-filled with that scheduled admission date" do
    get operations_calendar_url, params: { start: "2026-01-01", days: 1 }
    assert_response :success
    assert_select "a[href='#{new_hospitalization_path(scheduled_admission_date: '2026-01-01')}']"
  end

  test "root routes to the operations calendar" do
    get root_url
    assert_response :success
    assert_select "h1.app-page-title", text: "Operations Calendar"
  end

  test "a member (non-admin) can view the calendar" do
    sign_out
    sign_in_as(users(:member))

    get operations_calendar_url
    assert_response :success
  end
end
