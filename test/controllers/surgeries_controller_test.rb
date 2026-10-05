require "test_helper"

class SurgeriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @surgery = surgeries(:one)
  end

  test "index does not error out on a crafted Array page param" do
    get surgeries_url, params: { page: [ "1" ] }
    assert_response :success
  end

  test "index renders a ledger table with patient id and name stacked in one cell" do
    get surgeries_url, params: { all: "1" }
    assert_response :success
    assert_select "table.app-ledger"
    assert_select "table.app-ledger td.ledger-patient" do
      assert_select ".ledger-primary"
      assert_select ".ledger-secondary"
    end
  end

  test "index shows the weekday next to each surgery date, coloured for Sundays" do
    get surgeries_url, params: { performed_from: "2026-03-01", performed_to: "2026-03-02" }

    assert_select "span.app-date-holiday", text: "2026-03-01 (Sun)"
    assert_select "td span", text: "2026-03-02 (Mon)"
  end

  test "index marks a closed holiday date with the holiday colour" do
    surgeries(:two).update!(surgery_date: holidays(:national_holiday).date)

    get surgeries_url, params: { performed_from: "2026-03-10", performed_to: "2026-03-10" }

    assert_select "span.app-date-holiday", text: "2026-03-10 (Tue)"
  end

  test "index does not query holidays once per surgery" do
    holiday_queries = 0
    counter = ->(*, payload) { holiday_queries += 1 if payload[:sql].match?(/FROM "holidays"/) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      get surgeries_url, params: { performed_from: "2026-01-01" }
    end

    assert_equal 1, holiday_queries
  end

  test "index without params defaults to surgeries from seven days ago and pre-fills the date" do
    travel_to Date.new(2026, 10, 5) do
      recent = create_surgery(surgery_date: "2026-09-28")
      old = create_surgery(surgery_date: "2026-09-27", operator_name: "Dr. Old")

      get surgeries_url

      assert_response :success
      assert_select "tr td a[href=?]", surgery_path(recent)
      assert_select "tr td a[href=?]", surgery_path(old), count: 0
      assert_select "input[name=performed_from][value=?]", "2026-09-28"
    end
  end

  test "default index lists surgeries in ascending date order with undated ones last" do
    travel_to Date.new(2026, 10, 5) do
      later = create_surgery(surgery_date: "2026-10-20")
      sooner = create_surgery(surgery_date: "2026-10-06")
      undated = create_surgery(surgery_date: nil)

      get surgeries_url

      assert_equal [ sooner, later, undated ].map(&:id), surgery_ids_in_table
    end
  end

  test "all dates link shows older surgeries in ascending order" do
    travel_to Date.new(2026, 10, 5) do
      recent = create_surgery(surgery_date: "2026-10-06")

      get surgeries_url, params: { all: "1" }

      dates = Surgery.where(id: surgery_ids_in_table).index_by(&:id).values_at(*surgery_ids_in_table).map(&:surgery_date)
      assert_equal dates.compact.sort, dates.compact
      assert_equal surgery_ids_in_table.size, Surgery.count
      assert_includes surgery_ids_in_table, surgeries(:one).id
      assert_includes surgery_ids_in_table, recent.id
      assert_select "input[name=performed_from][value]", count: 0
    end
  end

  test "index offers an all dates link and clear returns to the default view" do
    get surgeries_url

    assert_select "a[href=?]", surgeries_path(all: 1), text: I18n.t("surgeries.index.show_all_link")

    get surgeries_url, params: { all: "1" }

    assert_select "a[href=?]", surgeries_path, text: I18n.t("common.clear")
  end

  test "paging through the default view stays in the default range" do
    travel_to Date.new(2026, 10, 5) do
      get surgeries_url, params: { page: 1 }

      assert_select "input[name=performed_from][value=?]", "2026-09-28"
    end
  end

  test "an explicit performed_from is honoured and undated surgeries stay excluded" do
    travel_to Date.new(2026, 10, 5) do
      create_surgery(surgery_date: nil)

      get surgeries_url, params: { performed_from: "2026-03-02" }

      assert_equal [ surgeries(:two).id ], surgery_ids_in_table.first(1)
      assert_not_includes surgery_ids_in_table, Surgery.undated.first.id
    end
  end

  test "an explicitly blank performed_from shows every dated surgery" do
    get surgeries_url, params: { performed_from: "", keyword: "" }

    assert_includes surgery_ids_in_table, surgeries(:one).id
  end

  test "pagination links keep the all dates param" do
    26.times { |i| create_surgery(surgery_date: "2026-04-#{format("%02d", i + 1)}") }

    get surgeries_url, params: { all: "1" }

    assert_select "a[href*=?]", "all=1", text: I18n.t("shared.pagination.next")
  end

  test "index filters by keyword" do
    get surgeries_url, params: { keyword: "jane" }
    assert_response :success
    assert_match(/Jane Smith/, @response.body)
    assert_no_match(/John Doe/, @response.body)
  end

  test "index shows the operator and assistant of each surgery" do
    surgeries(:one).update!(operator_name: "Dr. Operator", assistant_name: "Dr. Assistant")

    get surgeries_url, params: { all: "1" }

    assert_select "th span", text: "Operator"
    assert_select "td.ledger-operator" do
      assert_select ".ledger-primary", text: "Dr. Operator"
      assert_select ".ledger-secondary", text: "Dr. Assistant"
    end
  end

  test "index finds surgeries by operator name through the keyword filter" do
    surgeries(:two).update!(operator_name: "Dr. Zeta")

    get surgeries_url, params: { keyword: "zeta" }

    assert_response :success
    assert_match(/Jane Smith/, @response.body)
    assert_no_match(/John Doe/, @response.body)
  end

  test "index passes each filter param through to the surgery scope" do
    surgeries(:one).update!(slot_category: "off_slot", location: "Cath Lab Suite")
    undated = create_surgery(surgery_date: nil)
    {
      { anesthesia_method: "Spinal" } => [ surgeries(:two), surgeries(:one) ],
      { scheduling_type: "emergency" } => [ surgeries(:emergency_one), surgeries(:two) ],
      { slot_category: "off_slot" } => [ surgeries(:one), surgeries(:two) ],
      { surgery_procedure_id: surgery_procedures(:appendectomy).id } => [ surgeries(:one), surgeries(:two) ],
      { undated: "1" } => [ undated, surgeries(:one) ]
    }.each do |filter, (included, excluded)|
      get surgeries_url, params: filter

      assert_response :success
      assert_includes surgery_ids_in_table, included.id, "expected #{filter} to include surgery #{included.id}"
      assert_not_includes surgery_ids_in_table, excluded.id, "expected #{filter} to exclude surgery #{excluded.id}"
    end
  end

  test "index shows empty filtered message when filtering by slot_category matches nothing" do
    Surgery.where(slot_category: "off_slot").destroy_all

    get surgeries_url, params: { slot_category: "off_slot" }
    assert_response :success
    assert_select "td", text: I18n.t("surgeries.index.empty_filtered")
  end

  test "index shows the assigned slot, and flags elective surgeries without one" do
    get surgeries_url, params: { all: "1" }
    assert_response :success
    assert_match(/Slot 1/, @response.body)          # surgeries(:three) and (:four)
    assert_match(/No slot assigned/, @response.body) # surgeries(:six)
  end

  test "index shows the day's whole number of slots (total_slots), not the raw fractional slot_count" do
    ElectiveSlotRule.find_by(day_of_week: surgeries(:three).surgery_date.wday).update!(slot_count: 2.5, slot_duration_minutes: 240)

    get surgeries_url, params: { all: "1" }
    assert_response :success
    assert_match(%r{Slot 1 / 3}, @response.body)
    assert_no_match(/2\.5/, @response.body)
  end

  test "new renders the patient picker field instead of a patient dropdown" do
    get new_surgery_url

    assert_response :success
    assert_select "select[name='surgery[patient_id]']", count: 0
    assert_select "input[type=hidden][name='surgery[patient_id]']"
    assert_select "a[href='#{picker_patients_path}']"
  end

  test "new shows the day's whole number of slots (total_slots) in the configured-slots hint" do
    ElectiveSlotRule.find_by(day_of_week: 2).update!(slot_count: 2.5, slot_duration_minutes: 240)

    get new_surgery_url

    assert_response :success
    assert_match(/Tuesday: 3/, @response.body)
    assert_no_match(/Tuesday: 2\.5/, @response.body)
  end

  test "new without a selected patient shows no patient diagnoses from any patient" do
    get new_surgery_url

    assert_response :success
    assert_no_match(/Right Appendicitis/, @response.body)
    assert_no_match(/Hypertension/, @response.body)
    assert_no_match(/Bilateral Pneumonia/, @response.body)
  end

  test "new prefills the surgery date and patient from params" do
    get new_surgery_url(patient_id: patients(:one).id, surgery_date: "2027-02-03")

    assert_response :success
    assert_select "input#surgery_surgery_date[value=?]", "2027-02-03"
  end

  test "new ignores an unparsable surgery date" do
    get new_surgery_url(surgery_date: "not-a-date")

    assert_response :success
    assert_select "input#surgery_surgery_date:not([value])"
  end

  test "new ignores a crafted array surgery date" do
    get new_surgery_url, params: { surgery_date: [ "2027-02-03" ] }

    assert_response :success
    assert_select "input#surgery_surgery_date:not([value])"
  end

  # Nothing is linked yet on a brand new surgery, so the form itself carries no
  # diagnosis at all: they are fetched, patient-scoped, by the picker modal.
  test "new scoped to a patient offers that patient's diagnosis picker without listing any diagnosis" do
    get new_surgery_url(patient_id: patients(:one).id)

    assert_response :success
    assert_select "a[data-turbo-frame='surgery_diagnosis_picker_frame'][href=?]",
                  diagnosis_picker_surgeries_path(patient_id: patients(:one).id)
    assert_no_match(/Right Appendicitis/, @response.body)
    assert_no_match(/Hypertension/, @response.body)
    assert_no_match(/Bilateral Pneumonia/, @response.body)
  end

  test "edit shows only the surgery's patient diagnoses, with existing links checked" do
    get edit_surgery_url(@surgery)

    assert_response :success
    assert_match(/Right Appendicitis/, @response.body)
    assert_no_match(/Bilateral Pneumonia/, @response.body)
  end

  test "patient_fields returns the picker link scoped to the requested patient" do
    get patient_fields_surgeries_url(patient_id: patients(:one).id)

    assert_response :success
    assert_select "turbo-frame#surgery_patient_scoped_fields"
    assert_select "a[data-turbo-frame='surgery_diagnosis_picker_frame'][href=?]",
                  diagnosis_picker_surgeries_path(patient_id: patients(:one).id)
    assert_no_match(/Bilateral Pneumonia/, @response.body)
  end

  test "patient_fields without a patient_id shows the select-patient-first empty state" do
    get patient_fields_surgeries_url

    assert_response :success
    assert_match(/#{Regexp.escape(I18n.t("surgeries.form.select_patient_first"))}/, @response.body)
  end

  test "show back button goes to the surgery list by default" do
    get surgery_url(@surgery)

    assert_select "a.btn-circle[href=?]", surgeries_path
  end

  test "show back button returns to the calendar day when opened from the calendar" do
    get surgery_url(@surgery, from: "calendar", start: "2026-02-20", days: 30)

    assert_select "a.btn-circle[href=?]", operations_calendar_path(start: "2026-02-20", days: 30, anchor: "day-2026-03-01")
  end

  test "show carries the calendar origin over to the edit link" do
    get surgery_url(@surgery, from: "calendar", start: "2026-02-20", days: 30)

    assert_select "a[href=?]", edit_surgery_path(@surgery, from: "calendar", start: "2026-02-20", days: 30)
  end

  test "edit back button returns to the calendar when opened from the calendar" do
    get edit_surgery_url(@surgery, from: "calendar", start: "2026-02-20", days: 30)

    assert_select "a.btn-circle[href=?]", operations_calendar_path(start: "2026-02-20", days: 30, anchor: "day-2026-03-01")
  end

  test "new back button returns to the calendar when opened from the calendar" do
    get new_surgery_url(from: "calendar", start: "2026-02-20", days: 30)

    assert_select "a.btn-circle[href=?]", operations_calendar_path(start: "2026-02-20", days: 30)
  end

  test "invalid calendar origin params are ignored" do
    [
      { from: "calendar", start: "not-a-date", days: 30 },
      { from: "calendar", start: "2026-02-20", days: 9999 },
      { from: "calendar", start: [ "2026-02-20" ], days: [ "5" ] },
      { from: "https://evil.example/", start: "2026-02-20", days: 30 },
      { from: "//evil.example", start: "//evil.example", days: 30 }
    ].each do |params|
      get surgery_url(@surgery, **params)

      assert_response :success
      assert_select "a.btn-circle[href*=?]", "evil", count: 0
      assert_select "a.btn-circle[href*=?]", "not-a-date", count: 0
      assert_select "a.btn-circle[href*=?]", "9999", count: 0
    end
  end

  test "an unknown from value keeps the back button on the surgery list" do
    get surgery_url(@surgery, from: "elsewhere", start: "2026-02-20", days: 30)

    assert_select "a.btn-circle[href=?]", surgeries_path
  end

  test "create redirects to the calendar with the day anchored and highlighted" do
    travel_to Date.new(2026, 10, 5) do
      post surgeries_url, params: { surgery: valid_surgery_params(surgery_date: "2026-10-12") }

      assert_redirected_to operations_calendar_path(highlight: "2026-10-12", anchor: "day-2026-10-12")
    end
  end

  test "create redirects to a calendar starting a week before an out-of-range date" do
    travel_to Date.new(2026, 10, 5) do
      post surgeries_url, params: { surgery: valid_surgery_params(surgery_date: "2027-03-03") }

      assert_redirected_to operations_calendar_path(start: "2027-02-24", highlight: "2027-03-03", anchor: "day-2027-03-03")
    end
  end

  test "create for an undated surgery redirects to the surgery" do
    post surgeries_url, params: { surgery: valid_surgery_params(surgery_date: "", surgery_date_status: "undecided") }

    assert_redirected_to surgery_url(Surgery.order(:id).last)
  end

  test "create flash links to the surgery details" do
    post surgeries_url, params: { surgery: valid_surgery_params(surgery_date: "2026-03-03") }
    follow_redirect!

    assert_select ".alert-success a[href=?]", surgery_path(Surgery.order(:id).last), text: I18n.t("common.view_details")
  end

  test "update redirects to the calendar with the highlighted day" do
    patch surgery_url(@surgery), params: { surgery: { surgery_date: "2026-03-05" } }

    assert_redirected_to calendar_url_for(Date.new(2026, 3, 5))
    assert_response :see_other
  end

  test "update to an undated surgery redirects to the surgery" do
    patch surgery_url(@surgery), params: { surgery: { surgery_date: "", surgery_date_status: "undecided" } }

    assert_redirected_to surgery_url(@surgery)
  end

  test "hospitalization surgery follow-up ends on the calendar" do
    post hospitalizations_url, params: { hospitalization: {
      patient_id: patients(:two).id, purpose: "surgery", scheduled_admission_date: "2026-10-10",
      scheduled_surgery_date: "2026-10-12", planned_days: 3,
      hospitalization_diagnoses_attributes: { "0" => { diagnosis_id: diagnoses(:pneumonia).id } }
    } }
    assert_redirected_to new_surgery_url(patient_id: patients(:two).id, surgery_date: "2026-10-12")

    travel_to Date.new(2026, 10, 5) do
      post surgeries_url, params: { surgery: valid_surgery_params(surgery_date: "2026-10-12") }

      assert_redirected_to operations_calendar_path(highlight: "2026-10-12", anchor: "day-2026-10-12")
    end
  end

  test "should create surgery" do
    assert_difference("Surgery.count") do
      post surgeries_url, params: { surgery: {
        patient_id: patients(:one).id,
        patient_diagnosis_ids: [ patient_diagnoses(:appendicitis).id, patient_diagnoses(:hypertension).id ],
        surgery_date: "2026-03-03",
        anesthesia_method: "General",
        duration_hours: 2.0,
        surgery_procedure_selections_attributes: {
          "0" => { surgery_procedure_id: surgery_procedures(:cholecystectomy).id, laterality: "bilateral" },
          "1" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "left" }
        }
      } }
    end

    assert_redirected_to calendar_url_for(Surgery.last.surgery_date)
  assert_equal [ patient_diagnoses(:appendicitis).id, patient_diagnoses(:hypertension).id ].sort, Surgery.last.patient_diagnoses.ids.sort
    assert_equal [ "Cholecystectomy", "Appendectomy" ], Surgery.last.procedure_names
    assert_equal [ "bilateral", "left" ], Surgery.last.surgery_procedure_selections.order(:id).pluck(:laterality)
    assert_equal "Bilateral Cholecystectomy, Left Appendectomy", Surgery.last.display_procedure_name
  end

  test "should create surgery with simultaneous slot_category and target_department" do
    assert_difference("Surgery.count") do
      post surgeries_url, params: { surgery: {
        patient_id: patients(:one).id,
        surgery_date: "2026-03-03",
        anesthesia_method: "General",
        duration_hours: 2.0,
        slot_category: "simultaneous",
        target_department: "Gynecology",
        surgery_procedure_selections_attributes: {
          "0" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
        }
      } }
    end

    assert_redirected_to calendar_url_for(Surgery.last.surgery_date)
    created = Surgery.last
    assert_equal "simultaneous", created.slot_category
    assert_equal "Gynecology", created.target_department
    assert_nil created.slot_number
  end

  test "should create surgery with off_slot and location" do
    assert_difference("Surgery.count") do
      post surgeries_url, params: { surgery: {
        patient_id: patients(:one).id,
        surgery_date: "2026-03-03",
        anesthesia_method: "Local",
        duration_hours: 1.0,
        slot_category: "off_slot",
        location: "Cath Lab 1",
        surgery_procedure_selections_attributes: {
          "0" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "none" }
        }
      } }
    end

    assert_redirected_to calendar_url_for(Surgery.last.surgery_date)
    created = Surgery.last
    assert_equal "off_slot", created.slot_category
    assert_equal "Cath Lab 1", created.location
    assert_nil created.slot_number
  end

  test "should create a surgery with an undecided surgery_date" do
    assert_difference("Surgery.count") do
      post surgeries_url, params: { surgery: {
        patient_id: patients(:one).id,
        surgery_date: "",
        surgery_date_status: "undecided",
        anesthesia_method: "General",
        duration_hours: 1.0,
        surgery_procedure_selections_attributes: {
          "0" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
        }
      } }
    end

    assert_redirected_to surgery_url(Surgery.last)
    assert_nil Surgery.last.surgery_date
  end

  test "rejects a surgery marked scheduled with a blank surgery_date" do
    assert_no_difference("Surgery.count") do
      post surgeries_url, params: { surgery: {
        patient_id: patients(:one).id,
        surgery_date: "",
        surgery_date_status: "scheduled",
        anesthesia_method: "General",
        duration_hours: 1.0,
        surgery_procedure_selections_attributes: {
          "0" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
        }
      } }
    end

    assert_response :unprocessable_entity
  end

  test "should create a surgery with operator_name assistant_name and operation_order" do
    assert_difference("Surgery.count") do
      post surgeries_url, params: { surgery: {
        patient_id: patients(:one).id,
        surgery_date: "2026-03-05",
        operator_name: "Dr. A",
        assistant_name: "Dr. B",
        operation_order: 1,
        anesthesia_method: "General",
        duration_hours: 1.0,
        surgery_procedure_selections_attributes: {
          "0" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
        }
      } }
    end

    surgery = Surgery.last
    assert_equal "Dr. A", surgery.operator_name
    assert_equal "Dr. B", surgery.assistant_name
    assert_equal 1, surgery.operation_order
  end

  test "should create an emergency surgery on an unconfigured weekday at night" do
    assert_difference("Surgery.count") do
      post surgeries_url, params: { surgery: {
        patient_id: patients(:one).id,
        patient_diagnosis_ids: [ patient_diagnoses(:appendicitis).id ],
        surgery_date: "2026-03-01",
        scheduling_type: "emergency",
        start_time: "02:15",
        anesthesia_method: "General",
        duration_hours: 1.0,
        surgery_procedure_selections_attributes: {
          "0" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
        }
      } }
    end

    assert_redirected_to calendar_url_for(Surgery.last.surgery_date)
    assert Surgery.last.emergency?
    assert_equal "02:15", Surgery.last.start_time_display
  end

  test "should create an elective surgery beyond the configured slot capacity" do
    assert_difference("Surgery.count") do
      post surgeries_url, params: { surgery: {
        patient_id: patients(:one).id,
        patient_diagnosis_ids: [ patient_diagnoses(:appendicitis).id ],
        surgery_date: "2026-03-03",
        scheduling_type: "elective",
        anesthesia_method: "General",
        duration_hours: 1.0,
        surgery_procedure_selections_attributes: {
          "0" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
        }
      } }
    end

    assert_redirected_to calendar_url_for(Surgery.last.surgery_date)
    assert Surgery.last.elective?
  end

  test "show displays the surgery date with its weekday" do
    get surgery_url(@surgery)

    assert_select "span.app-date-holiday", text: "2026-03-01 (Sun)"
  end

  test "show does not issue additional queries for extra patient_diagnoses or procedure selections" do
    surgery = surgeries(:two) # starts with 1 diagnosis, 1 procedure selection
    get surgery_url(surgery) # warm-up: the first request in a process loads schema and session state
    fewer_queries = capture_query_count { get surgery_url(surgery) }

    extra_diagnosis = surgery.patient.patient_diagnoses.create!(diagnosis: diagnoses(:fracture), diagnosed_on: Date.new(2026, 4, 10))
    surgery.surgery_diagnosis_links.create!(patient_diagnosis: extra_diagnosis)
    surgery.surgery_procedure_selections.create!(surgery_procedure: surgery_procedures(:cholecystectomy))

    more_queries = capture_query_count { get surgery_url(surgery) } # now 2 diagnoses, 2 procedure selections

    assert_equal fewer_queries, more_queries
  end

  test "show displays a holiday badge when the surgery date is a holiday" do
    holiday = holidays(:national_holiday)
    surgery = Surgery.create!(
      patient: patients(:one),
      surgery_date: holiday.date,
      scheduling_type: "elective",
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: [ { surgery_procedure_id: surgery_procedures(:appendectomy).id } ]
    )

    get surgery_url(surgery)

    assert_response :success
    assert_match(/#{Regexp.escape(holiday.name)}/, @response.body)
  end

  test "show does not display a holiday badge on a non-holiday date" do
    get surgery_url(@surgery)
    assert_response :success
    assert_no_match(/Vernal Equinox Day/, @response.body)
  end

  test "show does not display a holiday badge for a comment-only day (holiday: false)" do
    note_only = Holiday.create!(date: @surgery.surgery_date, holiday: false, note: "Fire drill today")

    get surgery_url(@surgery)

    assert_response :success
    assert_select ".badge-secondary", count: 0
  ensure
    note_only&.destroy
  end

  test "show displays the day's whole number of slots (total_slots), not the raw fractional slot_count" do
    surgery = surgeries(:three) # Tuesday, slot_number 1
    ElectiveSlotRule.find_by(day_of_week: surgery.surgery_date.wday).update!(slot_count: 2.5, slot_duration_minutes: 240)

    get surgery_url(surgery)

    assert_response :success
    assert_match(%r{Slot 1 of 3}, @response.body)
    assert_no_match(/2\.5/, @response.body)
  end

  test "should update surgery" do
    patch surgery_url(@surgery), params: { surgery: {
      patient_id: @surgery.patient_id,
      patient_diagnosis_ids: [ patient_diagnoses(:appendicitis).id, patient_diagnoses(:hypertension).id ],
      surgery_date: @surgery.surgery_date,
      anesthesia_method: @surgery.anesthesia_method,
      duration_hours: @surgery.duration_hours,
      surgery_procedure_selections_attributes: {
        "0" => {
          id: surgery_procedure_selections(:one_appendectomy).id,
          surgery_procedure_id: surgery_procedures(:updated_procedure).id,
          laterality: "left"
        },
        "1" => {
          id: surgery_procedure_selections(:one_knee_arthroscopy).id,
          surgery_procedure_id: surgery_procedures(:appendectomy).id,
          laterality: "right"
        }
      }
    } }

    assert_redirected_to calendar_url_for(@surgery.surgery_date)
    @surgery.reload
    assert_equal [ patient_diagnoses(:appendicitis).id, patient_diagnoses(:hypertension).id ].sort, @surgery.patient_diagnoses.ids.sort
    assert_equal [ "Updated Procedure", "Appendectomy" ], @surgery.procedure_names
    assert_equal [ "left", "right" ], @surgery.surgery_procedure_selections.order(:id).pluck(:laterality)
    assert_equal "Left Updated Procedure, Right Appendectomy", @surgery.display_procedure_name
  end

  test "should respond with unprocessable entity when procedures are swapped between rows" do
    patch surgery_url(@surgery), params: { surgery: {
      patient_id: @surgery.patient_id,
      surgery_date: @surgery.surgery_date,
      anesthesia_method: @surgery.anesthesia_method,
      surgery_procedure_selections_attributes: {
        "0" => {
          id: surgery_procedure_selections(:one_appendectomy).id,
          surgery_procedure_id: surgery_procedures(:knee_arthroscopy).id
        },
        "1" => {
          id: surgery_procedure_selections(:one_knee_arthroscopy).id,
          surgery_procedure_id: surgery_procedures(:appendectomy).id
        }
      }
    } }

    assert_response :unprocessable_entity
    assert_equal [ "Appendectomy", "Knee arthroscopy" ], @surgery.reload.procedure_names
  end

  test "should not mask a unique violation from an unrelated constraint as a procedure swap error" do
    unrelated_violation = ActiveRecord::RecordNotUnique.new(
      "SQLite3::ConstraintException: UNIQUE constraint failed: surgery_diagnosis_links.surgery_id, surgery_diagnosis_links.patient_diagnosis_id"
    )

    Surgery.define_method(:update) { |*| raise unrelated_violation }

    assert_raises(ActiveRecord::RecordNotUnique) do
      patch surgery_url(@surgery), params: { surgery: {
        patient_id: @surgery.patient_id,
        surgery_date: @surgery.surgery_date,
        anesthesia_method: @surgery.anesthesia_method
      } }
    end
  ensure
    Surgery.remove_method(:update) if Surgery.instance_methods(false).include?(:update)
  end

  test "should reject diagnosis belonging to another patient" do
    assert_no_difference("Surgery.count") do
      post surgeries_url, params: { surgery: {
        patient_id: patients(:one).id,
        patient_diagnosis_ids: [ patient_diagnoses(:appendicitis).id, patient_diagnoses(:pneumonia).id ],
        surgery_date: "2026-03-03",
        anesthesia_method: "General",
        duration_hours: 2.0,
        surgery_procedure_selections_attributes: {
          "0" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
        }
      } }
    end

    assert_response :unprocessable_entity
  end

  test "should destroy surgery" do
    assert_difference("Surgery.count", -1) do
      delete surgery_url(@surgery)
    end

    assert_redirected_to surgeries_url
  end

  private

    def capture_query_count
      count = 0
      counter = ->(*) { count += 1 }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
      count
    end

  test "diagnosis picker lists only the given patient's diagnoses" do
    get diagnosis_picker_surgeries_url, params: { patient_id: patients(:one).id }

    assert_response :success
    assert_match "surgery_diagnosis_picker_frame", response.body
    assert_match patient_diagnoses(:appendicitis).display_name, response.body
    assert_no_match(/#{patient_diagnoses(:pneumonia).display_name}/, response.body)
  end

  test "diagnosis picker without a patient renders an empty state" do
    get diagnosis_picker_surgeries_url

    assert_response :success
    assert_no_match(/#{patient_diagnoses(:appendicitis).display_name}/, response.body)
  end

  private

    # What the app redirects to after saving a surgery on `date` (today being
    # the real date, so only dates outside the default range start a week back).
    def calendar_url_for(date)
      range = OperationsCalendar.default_range
      start = range.cover?(date) ? nil : (date - 7).iso8601
      operations_calendar_url(start: start, highlight: date.iso8601, anchor: "day-#{date.iso8601}")
    end

    def valid_surgery_params(overrides = {})
      {
        patient_id: patients(:one).id, anesthesia_method: "General", duration_hours: 1.0,
        surgery_procedure_selections_attributes: { "0" => { surgery_procedure_id: surgery_procedures(:appendectomy).id } }
      }.merge(overrides)
    end

    def create_surgery(surgery_date:, operator_name: nil)
      Surgery.create!(
        patient: patients(:one), surgery_date: surgery_date, operator_name: operator_name,
        anesthesia_method: "General", duration_hours: 1.0,
        surgery_procedure_selections_attributes: [ { surgery_procedure_id: surgery_procedures(:appendectomy).id } ]
      )
    end

    def surgery_ids_in_table
      css_select("table.app-ledger td.ledger-actions a[href^='/surgeries/']").filter_map do |a|
        a["href"][%r{\A/surgeries/(\d+)\z}, 1]&.to_i
      end.uniq
    end
end
