require "test_helper"

class CalendarDaysControllerTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html", "X-Live-Update" => "1" }.freeze
  DATE = "2026-03-03".freeze

  setup { sign_in_as(users(:member)) }

  test "a non-admin gets the day's tbody as a turbo stream replace" do
    get calendar_day_url(DATE), params: { start: "2026-03-01", days: "7", view: "surgery" }, headers: TURBO

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=replace][target=?]", "day-#{DATE}" do
      assert_select "template tbody#day-#{DATE}"
    end
  end

  test "each view renders its own day" do
    %w[surgery examination chemotherapy admission].each do |view|
      get calendar_day_url(DATE), params: { view: view }, headers: TURBO

      assert_response :success, view
      assert_select "turbo-stream[target=?] template tbody#day-#{DATE}", "day-#{DATE}"
    end
  end

  test "the chemotherapy day lists its rows and keeps the view in its links" do
    hospitalizations(:two).update_columns(purpose: "chemotherapy", scheduled_procedure_date: Date.new(2026, 3, 3), scheduled_admission_date: Date.new(2026, 3, 3),
                                          admission_date: nil, discharge_date: nil, chemotherapy_protocol_id: chemotherapy_protocols(:protocol_a).id)
    get calendar_day_url(DATE), params: { view: "chemotherapy", start: "2026-03-01", days: "7" }, headers: TURBO

    assert_response :success
    assert_select "template tbody#day-#{DATE} tr.oc-exam", 1
    assert_select "template tbody#day-#{DATE} tr.oc-exam", text: /Protocol A/
    assert_includes response.body, "purpose=chemotherapy"
  end

  test "the admin-only edit link is not shown to a member" do
    get calendar_day_url(DATE), params: { view: "surgery" }, headers: TURBO

    assert_no_match(/day_notes\/#{DATE}\/edit/, response.body)
  end

  test "the viewer's filter is honored" do
    get calendar_day_url(DATE), params: { view: "surgery" }, headers: TURBO
    unfiltered = response.body.scan("<tr").size

    get calendar_day_url(DATE), params: { view: "surgery", mine: "1" }, headers: TURBO
    assert_response :success
    assert_operator response.body.scan("<tr").size, :<, unfiltered
  end

  test "a bad date is not found" do
    get calendar_day_url("nope"), headers: TURBO

    assert_response :not_found
  end

  test "signed out it goes to the sign-in page" do
    sign_out
    get calendar_day_url(DATE), headers: TURBO

    assert_redirected_to login_url
  end

  test "the endpoint does not extend the session when asked as a live update" do
    get calendar_day_url(DATE), headers: TURBO
    assert_equal users(:member).id, request.session[:user_id]
  end
end
