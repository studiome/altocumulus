require "test_helper"

class OperationsCalendarControllerTest < ActionDispatch::IntegrationTest
  test "shows exactly 50 days by default, not 51" do
    get operations_calendar_url
    assert_response :success
    assert_select ".oc-day", 50
  end

  test "calendar shows the partner department and the location of non-regular surgeries" do
    surgeries(:one).update!(slot_category: "simultaneous", department: departments(:gynecology))
    surgeries(:emergency_one).update!(slot_category: "off_slot", surgery_location: surgery_locations(:cath_lab))

    get operations_calendar_url, params: { start: "2026-03-01" }

    assert_response :success
    assert_match "Gynecology", response.body
    assert_match "Cath Lab", response.body
  end

  test "the day cell lists each special slot resource with used/lanes, red when over" do
    SpecialSlotRule.create!(resource: surgery_locations(:cath_lab), day_of_week: 2, slot_count: 2)
    SpecialSlotRule.create!(resource: surgical_devices(:robot_a), day_of_week: 2, slot_count: 1)
    surgeries(:three).update_columns(surgery_location_id: surgery_locations(:cath_lab).id)
    surgeries(:four).update_columns(surgical_device_id: surgical_devices(:robot_a).id)
    surgeries(:five).update_columns(surgical_device_id: surgical_devices(:robot_a).id)

    get operations_calendar_url, params: { start: "2026-03-03", days: 1 }

    assert_select "td.ledger-day .special-slot-line", 2
    assert_select "td.ledger-day .special-slot-line:not(.text-error)", text: "Cath Lab 1/2 lanes (60/480 min)"
    assert_select "td.ledger-day .special-slot-line.text-error", text: "Robot A 2/1 lanes (360/240 min)"
    assert_select "tr.ledger-band-warning td", text: /Robot A/
  end

  test "a date override replaces the weekly lanes and carries the changed marker on that line only" do
    SpecialSlotRule.create!(resource: surgery_locations(:cath_lab), day_of_week: 2, slot_count: 2)
    SpecialSlotRule.create!(resource: surgical_devices(:robot_a), day_of_week: 2, slot_count: 1)
    SpecialSlotDayOverride.create!(resource: surgery_locations(:cath_lab), date: "2026-03-03", slot_count: 1)

    get operations_calendar_url, params: { start: "2026-03-03", days: 1 }

    assert_select "td.ledger-day .special-slot-line", text: "Cath Lab 0/1 lanes (0/240 min) (changed)"
    assert_select "td.ledger-day .special-slot-line", text: "Robot A 0/1 lanes (0/240 min)"
  end

  test "admins get the edit-special-slots link and its frame, members do not" do
    get operations_calendar_url, params: { start: "2026-03-03", days: 1 }
    assert_select "td.ledger-day a[href^=?]", edit_day_special_slot_path("2026-03-03")
    assert_select "turbo-frame#day-special-slots-2026-03-03"

    sign_out
    sign_in_as(users(:member))
    get operations_calendar_url, params: { start: "2026-03-03", days: 1 }
    assert_select "a[href^=?]", edit_day_special_slot_path("2026-03-03"), 0
    assert_select "turbo-frame#day-special-slots-2026-03-03", 0
  end

  test "a day with no special resources shows no special slot line" do
    get operations_calendar_url, params: { start: "2026-03-03", days: 1 }
    assert_select ".special-slot-line", 0
  end

  test "a regular case with a special resource shows its badge and is not hatched as off-slot" do
    SpecialSlotRule.create!(resource: surgery_locations(:cath_lab), day_of_week: 2, slot_count: 1)
    surgeries(:three).update_columns(surgery_location_id: surgery_locations(:cath_lab).id, surgical_device_id: surgical_devices(:robot_a).id)

    with_site_config("ledger_columns" => { "operations_calendar" => %w[patient category] }) do
      get operations_calendar_url, params: { start: "2026-03-03", days: 1 }
    end

    assert_select "tr.oc-surgery .badge", text: "Cath Lab"
    assert_select "tr.oc-surgery .badge", text: "Robot A"
    assert_select "tr.oc-surgery.ledger-row-offslot", 0
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

  test "each day links to a new reservation pre-filled with that surgery date, from the date and a small add link" do
    get operations_calendar_url, params: { start: "2026-01-01", days: 1 }
    assert_response :success
    assert_select "a[href=?]", new_reservation_path(surgery_date: "2026-01-01", purpose: "surgery"), count: 2
    assert_select "a[href=?]", new_reservation_path(surgery_date: "2026-01-01", purpose: "surgery"), text: I18n.t("reservations.links.new_reservation")
  end

  test "a surgery that belongs to a hospitalization gets an edit link to the reservation form" do
    hospitalization = hospitalizations(:one)
    surgeries(:three).update_columns(hospitalization_id: hospitalization.id, patient_id: hospitalization.patient_id)

    get operations_calendar_url, params: { start: "2026-03-03", days: 1 }

    assert_select "tr.oc-surgery a[href=?]", edit_reservation_path(hospitalization), count: 1
    assert_select "tr.oc-surgery a[href=?]", edit_reservation_path(hospitalizations(:two)), count: 0
  end

  test "no edit link for a surgery of a deleted hospitalization or one without a hospitalization" do
    hospitalization = hospitalizations(:one)
    surgeries(:three).update_columns(hospitalization_id: hospitalization.id, patient_id: hospitalization.patient_id)
    hospitalization.discard!

    get operations_calendar_url, params: { start: "2026-03-03", days: 1 }

    assert_select "tr.oc-surgery a[href$='/edit']", count: 0
  end

  test "renders the days as one ledger table with a tbody per day" do
    get operations_calendar_url, params: { start: "2026-03-01", days: 3 }

    assert_select "table.app-ledger.oc-ledger" do
      assert_select "tbody.oc-day", 3
    end
  end

  test "every column header declares its own minimum width so the table scrolls instead of squeezing" do
    get operations_calendar_url, params: { start: "2026-03-01", days: 1 }

    assert_select "table.oc-ledger thead th[style*='--ledger-col-min']", SiteConfig.current.ledger_column_keys(:operations_calendar).size
  end

  test "a day cell spans all of that day's surgery rows and carries the date link" do
    get operations_calendar_url, params: { start: "2026-03-03", days: 1 }

    assert_select "tbody.oc-day tr.oc-surgery", 4 # four elective fixtures on 2026-03-03
    assert_select "tbody.oc-day td.ledger-day[rowspan='4']" do
      assert_select "a[href=?]", new_reservation_path(surgery_date: "2026-03-03", purpose: "surgery")
    end
    assert_select "tbody.oc-day td.ledger-day", 1
  end

  test "a day cell shows the date before the weekday" do
    get operations_calendar_url, params: { start: "2026-03-03", days: 1 }

    date = Date.new(2026, 3, 3)
    text = css_select("tbody.oc-day td.ledger-day").first.text
    date_index = text.index(I18n.l(date, format: :default))
    weekday_index = text.index(I18n.l(date, format: :weekday))

    assert date_index, "date text should be present"
    assert weekday_index, "weekday text should be present"
    assert_operator date_index, :<, weekday_index
  end

  test "each surgery row stacks patient id over name and links to the surgery" do
    get operations_calendar_url, params: { start: "2026-03-03", days: 1 }

    assert_select "tr.oc-surgery td.ledger-patient" do
      assert_select ".ledger-secondary", text: "H001"
      assert_select "a.ledger-primary[href=?]", surgery_path(surgeries(:three), from: "calendar", start: "2026-03-03", days: 1), text: "John Doe"
    end
  end

  test "each day body has a stable id for anchors" do
    get operations_calendar_url, params: { start: "2026-03-03", days: 2 }

    assert_select "tbody.oc-day#day-2026-03-03"
    assert_select "tbody.oc-day#day-2026-03-04"
  end

  test "the highlighted day is marked and gets the highlight controller" do
    get operations_calendar_url, params: { start: "2026-03-03", days: 2, highlight: "2026-03-04" }

    assert_select "tbody#day-2026-03-04.oc-day-highlight[data-controller='calendar-highlight']"
    assert_select "tbody#day-2026-03-03.oc-day-highlight", count: 0
  end

  test "an invalid highlight is ignored" do
    [ "nope", "2026-13-45", [ "2026-03-03" ] ].each do |value|
      get operations_calendar_url, params: { start: "2026-03-03", days: 2, highlight: value }

      assert_response :success
      assert_select ".oc-day-highlight", count: 0
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

  test "shows the referral source in its own column, not under the patient name" do
    surgery = surgeries(:one)
    hospitalizations(:one).update_columns(referred_from: "Riverside Clinic", adl: "Walker")

    get operations_calendar_url, params: { start: surgery.surgery_date.to_s, days: 1 }

    assert_response :success
    assert_select ".ledger-patient", text: /Riverside Clinic/, count: 0
    assert_select "tr.oc-surgery td:last-child .ledger-primary", text: "Riverside Clinic"
    assert_select "tr.oc-surgery td:last-child .ledger-secondary", text: "Walker"
  end

  test "shows nothing in the referral column when there is no referral source" do
    surgery = surgeries(:one)

    get operations_calendar_url, params: { start: surgery.surgery_date.to_s, days: 1 }

    assert_response :success
    assert_select "tr.oc-surgery td:last-child .ledger-primary", count: 0
  end

  test "the default header is the day cell plus the default columns, two tiers each" do
    get operations_calendar_url, params: { start: "2026-03-03", days: 1 }

    assert_select "thead th", 8
    assert_select "thead th:nth-child(2) span", count: 2
    assert_select "thead th:nth-child(2) span:nth-child(1)", text: "Start Time"
    assert_select "thead th:nth-child(2) span:nth-child(2)", text: "Slot"
    assert_select "thead th:last-child", text: /Referred From.*ADL/m
    assert_select "thead th:nth-child(7)", text: "Type"
  end

  test "the columns and their order follow the site config" do
    with_site_config("ledger_columns" => { "operations_calendar" => %w[patient time_slot] }) do
      get operations_calendar_url, params: { start: "2026-03-03", days: 1 }

      assert_select "thead th", 3
      assert_select "thead th:nth-child(2)", text: /Patient ID.*Name/m
      assert_select "thead th:nth-child(3)", text: /Start Time.*Slot/m
      assert_select "tr.oc-surgery + tr.oc-surgery td:first-child.ledger-patient" # later rows have no day cell
      assert_select "tr.oc-surgery", 4
    end
  end

  test "band rows and the empty-day row span the configured columns" do
    with_site_config("ledger_columns" => { "operations_calendar" => %w[patient time_slot] }) do
      get operations_calendar_url, params: { start: "2026-03-03", days: 3 }

      assert_select "tr.ledger-band-warning td[colspan='3']"
      assert_select "tr.oc-empty td[colspan='2']"
    end
    get operations_calendar_url, params: { start: "2026-03-03", days: 3 }
    assert_select "tr.ledger-band-warning td[colspan='8']"
    assert_select "tr.oc-empty td[colspan='7']"
  end

  test "the category column renders badges for emergency and partner department cases" do
    surgeries(:one).update_columns(slot_category: "simultaneous", department_id: departments(:gynecology).id,
                                   scheduling_type: "emergency")

    with_site_config("ledger_columns" => { "operations_calendar" => %w[patient category] }) do
      get operations_calendar_url, params: { start: "2026-03-01", days: 1 }

      assert_select "tr.oc-surgery .badge.badge-error", text: "Emergency"
      assert_select "tr.oc-surgery .badge", text: /Gynecology/
    end
  end

  test "a team column shows the team badge and the members for the surgery date" do
    config = { "features" => { "teams" => true }, "ledger_columns" => { "operations_calendar" => %w[patient team] } }
    surgeries(:one).update_columns(team_id: teams(:blue).id, surgery_date: Date.new(2026, 10, 20))

    with_site_config(config) do
      get operations_calendar_url, params: { start: "2026-10-20", days: 1 }

      assert_select "tr.oc-surgery .badge", text: "Blue Team"
      assert_select "tr.oc-surgery .ledger-secondary", text: /Alpha\(M\), Bravo\(S\)/
    end
  end

  test "an undecided team shows a gray badge in the team column and can be filtered" do
    config = { "features" => { "teams" => true }, "ledger_columns" => { "operations_calendar" => %w[patient team] } }
    surgeries(:one).update_columns(team_undecided: true, surgery_date: Date.new(2026, 10, 20))

    with_site_config(config) do
      get operations_calendar_url, params: { start: "2026-10-20", days: 1 }
      assert_select "tr.oc-surgery .badge", text: I18n.t("teams.undecided_badge")
      assert_select "select#calendar_team_id option[value='undecided']", text: I18n.t("teams.undecided_badge")

      get operations_calendar_url, params: { start: "2026-10-20", days: 1, team_id: "undecided" }
      assert_select "select#calendar_team_id option[value='undecided'][selected]"
      assert_select "tr.oc-surgery", count: 1

      get operations_calendar_url, params: { start: "2026-10-20", days: 1, team_id: teams(:blue).id }
      assert_select "tr.oc-surgery", count: 0
    end
  end

  test "the number of queries does not grow with the number of surgeries, even with every column" do
    columns = LedgerColumn.keys(:surgery).map(&:to_s)
    config = { "features" => { "teams" => true }, "ledger_columns" => { "operations_calendar" => columns } }
    date = Date.new(2030, 1, 8)
    add = lambda do |index|
      patient = Patient.create!(name: "Q#{index}", hospital_id: "Q#{index}", date_of_birth: Date.new(1970, 1, 1), sex: "male")
      hospitalization = Hospitalization.create!(patient: patient, reason: "x", scheduled_admission_date: date - 1,
                                                referred_from: "Clinic", team: teams(:blue), reservation_doctor: users(:admin),
                                                created_by: users(:member), transfer_status: "transferred_in",
                                                source_department: departments(:gynecology),
                                                hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:appendicitis).id } ])
      Surgery.create!(patient: patient, surgery_date: date, anesthesia_method: "General", hospitalization: hospitalization,
                      slot_category: "simultaneous", department: departments(:gynecology), team: teams(:red),
                      surgical_device: surgical_devices(:robot_a), performing_department: departments(:gynecology),
                      surgery_procedure_selections_attributes: [ { surgery_procedure_id: surgery_procedures(:appendectomy).id } ])
    end

    with_site_config(config) do
      add.call(1)
      one = count_queries { get operations_calendar_url, params: { start: date.to_s, days: 3 } }
      3.times { |i| add.call(i + 2) }
      many = count_queries { get operations_calendar_url, params: { start: date.to_s, days: 3 } }
      assert_equal one, many
    end
  end

  private

    def count_queries
      count = 0
      counter = ->(_name, _started, _finished, _unique_id, payload) do
        count += 1 unless payload[:cached] || payload[:name] == "SCHEMA"
      end
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
      count
    end
end
