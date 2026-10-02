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

  test "announcements are shown on the login page, not on the calendar" do
    get operations_calendar_url
    assert_response :success
    assert_no_match(/Winter schedule notice/, @response.body)
  end

  test "each day links to a new hospitalization pre-filled with that scheduled admission date" do
    get operations_calendar_url, params: { start: "2026-01-01", days: 1 }
    assert_response :success
    assert_select "a[href='#{new_hospitalization_path(scheduled_admission_date: '2026-01-01')}']"
  end

  test "renders the days as one ledger table with a tbody per day" do
    get operations_calendar_url, params: { start: "2026-03-01", days: 3 }

    assert_select "table.app-ledger.oc-ledger" do
      assert_select "tbody.oc-day", 3
    end
  end

  test "a day cell spans all of that day's surgery rows and carries the date link" do
    get operations_calendar_url, params: { start: "2026-03-03", days: 1 }

    assert_select "tbody.oc-day tr.oc-surgery", 4 # four elective fixtures on 2026-03-03
    assert_select "tbody.oc-day td.ledger-day[rowspan='4']" do
      assert_select "a[href=?]", new_hospitalization_path(scheduled_admission_date: "2026-03-03")
    end
    assert_select "tbody.oc-day td.ledger-day", 1
  end

  test "each surgery row stacks patient id over name and links to the surgery" do
    get operations_calendar_url, params: { start: "2026-03-03", days: 1 }

    assert_select "tr.oc-surgery td.ledger-patient" do
      assert_select ".ledger-secondary", text: "H001"
      assert_select "a.ledger-primary[href=?]", surgery_path(surgeries(:three)), text: "John Doe"
    end
  end

  test "surgery rows show the operator, duration in hours and slot" do
    surgeries(:three).update!(operator_name: "Dr. Operator", assistant_name: "Dr. Assistant")

    get operations_calendar_url, params: { start: "2026-03-03", days: 1 }

    assert_select "td.ledger-operator .ledger-primary", text: "Dr. Operator"
    assert_select "td.ledger-operator .ledger-secondary", text: "Dr. Assistant"
    assert_select "tr.oc-surgery", text: /1\.0 h/
    assert_select "tr.oc-surgery", text: /Slot 1/
  end

  test "an emergency surgery row is marked urgent" do
    get operations_calendar_url, params: { start: "2026-03-01", days: 1 }

    assert_select "tr.oc-surgery.ledger-row-urgent", 1
    assert_select "tr.oc-surgery", 2
  end

  test "a closed day shows a band row with the holiday name" do
    get operations_calendar_url, params: { start: "2026-03-10", days: 1 }

    assert_select "tr.ledger-band td", text: /Vernal Equinox Day/
  end

  test "a day without surgeries still shows its date and a placeholder row" do
    get operations_calendar_url, params: { start: "2026-03-10", days: 1 }

    assert_select "tbody.oc-day td.ledger-day[rowspan='1']"
    assert_select "tbody.oc-day tr.oc-empty td", text: /No surgeries scheduled/
  end

  test "slot warnings appear as a band row" do
    get operations_calendar_url, params: { start: "2026-03-03", days: 1 }

    assert_select "tr.ledger-band-warning td", text: /past its/
  end

  test "has no side pane: the ledger is the only content next to the announcements" do
    get operations_calendar_url, params: { start: "2026-03-01", days: 3 }

    assert_select "h3", text: Hospitalization.status_filter_options["waiting"], count: 0
    assert_select "h3", text: "Undated Surgeries", count: 0
    assert_select "h3", text: "Outside Regular Surgery Days", count: 0
    assert_select ".lg\\:col-span-2", 0
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
