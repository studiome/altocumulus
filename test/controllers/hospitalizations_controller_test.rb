require "test_helper"

class HospitalizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @hospitalization = hospitalizations(:one)
  end

  test "index.json excludes discarded hospitalizations" do
    @hospitalization.discard!

    get hospitalizations_url(format: :json)

    assert_response :success
    ids = JSON.parse(@response.body).map { |h| h["id"] }
    assert_not_includes ids, @hospitalization.id
  end

  test "index does not error out on a crafted Array page param" do
    get hospitalizations_url, params: { page: [ "1" ] }
    assert_response :success
  end

  test "index renders a ledger table with patient id and name stacked in one cell" do
    get hospitalizations_url
    assert_response :success
    assert_select "table.app-ledger"
    assert_select "table.app-ledger td.ledger-patient" do
      assert_select ".ledger-primary"
      assert_select ".ledger-secondary"
    end
  end

  test "index shows the weekday on the admission, discharge and scheduled surgery dates" do
    @hospitalization.update!(purpose: "surgery", scheduled_surgery_date: "2026-03-03")

    get hospitalizations_url, params: { admitted_from: "2026-03-01", admitted_to: "2026-03-01" }

    assert_select "span.app-date-holiday", text: "2026-03-01 (Sun)"
    assert_select "td span", text: "2026-03-06 (Fri)"
    assert_select "td span", text: "2026-03-03 (Tue)"
  end

  test "index shows the weekday on a scheduled admission date" do
    get hospitalizations_url, params: { admitted_from: "2026-10-01" }

    assert_select "td span", text: "2026-10-01 (Thu)"
  end

  test "index does not query holidays once per hospitalization" do
    holiday_queries = 0
    counter = ->(*, payload) { holiday_queries += 1 if payload[:sql].match?(/FROM "holidays"/) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      get hospitalizations_url, params: { admitted_from: "2026-01-01" }
    end

    assert_equal 1, holiday_queries
  end

  test "show displays every date with its weekday" do
    get hospitalization_url(@hospitalization)

    assert_select "span", text: "2026-03-01 (Sun)"
    assert_select "span", text: "2026-03-06 (Fri)"
  end

  test "deleted list shows the admission date with its weekday" do
    @hospitalization.discard!

    get deleted_hospitalizations_url

    assert_select "td span", text: "2026-03-01 (Sun)"
  end

  test "index without params defaults to admissions from seven days ago and pre-fills the date" do
    travel_to Date.new(2026, 10, 5) do
      get hospitalizations_url

      assert_response :success
      assert_select "input[name=admitted_from][value=?]", "2026-09-28"
      assert_equal [ hospitalizations(:four).id ], hospitalization_ids_in_table
    end
  end

  test "default index excludes admissions older than seven days" do
    travel_to Date.new(2026, 10, 5) do
      get hospitalizations_url

      assert_not_includes hospitalization_ids_in_table, hospitalizations(:one).id
      assert_not_includes hospitalization_ids_in_table, hospitalizations(:three).id
    end
  end

  test "index lists hospitalizations in ascending date order" do
    get hospitalizations_url, params: { all: "1" }

    assert_equal [ :one, :two, :three, :four ].map { |n| hospitalizations(n).id }, hospitalization_ids_in_table
  end

  test "all dates link shows older hospitalizations" do
    travel_to Date.new(2026, 10, 5) do
      get hospitalizations_url, params: { all: "1" }

      assert_includes hospitalization_ids_in_table, hospitalizations(:one).id
      assert_select "input[name=admitted_from][value]", count: 0
    end
  end

  test "index offers an all dates link and clear returns to the default view" do
    get hospitalizations_url

    assert_select "a[href=?]", hospitalizations_path(all: 1), text: I18n.t("hospitalizations.index.show_all_link")

    get hospitalizations_url, params: { all: "1" }

    assert_select "a[href=?]", hospitalizations_path, text: I18n.t("common.clear")
  end

  test "an explicit admitted_from is honoured" do
    get hospitalizations_url, params: { admitted_from: "2026-03-05", admitted_to: "2026-06-30" }

    assert_equal [ hospitalizations(:two).id, hospitalizations(:three).id ], hospitalization_ids_in_table
  end

  test "paging through the default view stays in the default range" do
    travel_to Date.new(2026, 10, 5) do
      get hospitalizations_url, params: { page: 1 }

      assert_select "input[name=admitted_from][value=?]", "2026-09-28"
    end
  end

  test "index filters by keyword" do
    get hospitalizations_url, params: { keyword: "jane" }
    assert_response :success
    assert_match(/Jane Smith/, @response.body)
    assert_no_match(/John Doe/, @response.body)
  end

  test "index filters by status" do
    get hospitalizations_url, params: { status: "in_hospital" }
    assert_response :success
    assert_match(/Observation/, @response.body)
    assert_no_match(/Community-acquired pneumonia/, @response.body)
  end

  test "index filters by diagnosis_id" do
    get hospitalizations_url, params: { diagnosis_id: diagnoses(:appendicitis).id, all: "1" }

    assert_equal [ hospitalizations(:three).id ], hospitalization_ids_in_table
  end

  test "index shows reservation status, purpose, and admin confirmation state" do
    get hospitalizations_url
    assert_response :success
    assert_match(/Requested|Waiting for Admission|Admission Date Fixed/, @response.body)
    assert_match(/Unconfirmed|Confirmed/, @response.body)
  end

  test "index spells out Length of Stay instead of the LOS abbreviation" do
    get hospitalizations_url
    assert_response :success

    headers = Nokogiri::HTML(@response.body).css("thead th span").map { |span| span.text.strip }
    assert_includes headers, "Length of Stay"
    assert_not_includes headers, "LOS"
  end

  test "index shows the finalized length of stay for a discharged hospitalization" do
    get hospitalizations_url, params: { all: "1" }
    assert_response :success

    assert_equal "6 days", length_of_stay_cell_for(@response.body, hospitalizations(:one).reason)
  end

  test "index shows the running day count for a hospitalization still admitted" do
    travel_to Date.new(2026, 6, 4) do
      get hospitalizations_url, params: { all: "1" }
      assert_response :success

      assert_equal "Day 4 (ongoing)", length_of_stay_cell_for(@response.body, hospitalizations(:three).reason)
    end
  end

  test "index shows a dash for a reservation that has not been admitted yet" do
    get hospitalizations_url, params: { all: "1" }
    assert_response :success

    assert_equal "-", length_of_stay_cell_for(@response.body, hospitalizations(:four).reason)
  end

  test "index orders reservation-only hospitalizations by scheduled_admission_date" do
    reservation = Hospitalization.create!(
      patient: patients(:two),
      scheduled_admission_date: Date.new(2027, 1, 1),
      reason: "Planned surgery",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ]
    )

    get hospitalizations_url, params: { all: "1" }
    assert_response :success

    body_index = @response.body.index(reservation.reason)
    other_index = @response.body.index(hospitalizations(:three).reason)
    assert body_index > other_index, "expected the furthest-out scheduled hospitalization to sort last"
  end

  test "new pre-fills the scheduled admission date from a query param" do
    get new_hospitalization_url, params: { scheduled_admission_date: "2027-02-01" }
    assert_response :success
    assert_select "input#hospitalization_scheduled_admission_date[value='2027-02-01']"
  end

  test "new renders the diagnosis picker frame and turbo-frame links into it" do
    get new_hospitalization_url
    assert_response :success
    assert_select "turbo-frame#diagnosis_picker_frame"
    assert_select "a[data-turbo-frame='diagnosis_picker_frame'][href=?]", picker_diagnoses_path
  end

  test "new renders the diagnosis picker field instead of a diagnosis dropdown" do
    get new_hospitalization_url

    assert_response :success
    assert_select "select[name^='hospitalization[hospitalization_diagnoses_attributes]']", count: 0
    assert_select "input[type=hidden][name=?]", "hospitalization[hospitalization_diagnoses_attributes][0][diagnosis_id]"
  end

  test "new renders the patient picker field instead of a patient dropdown" do
    get new_hospitalization_url

    assert_response :success
    assert_select "select[name='hospitalization[patient_id]']", count: 0
    assert_select "input[type=hidden][name='hospitalization[patient_id]']"
    assert_select "a[href='#{picker_patients_path}']"
  end

  test "should create hospitalization" do
    assert_difference("Hospitalization.count") do
      post hospitalizations_url, params: { hospitalization: {
        patient_id: patients(:one).id,
        admission_date: "2026-05-01",
        discharge_date: "2026-05-05",
        outcome: "recovered",
        discharge_destination: "home",
        planned_days: 4,
        reason: "Acute bronchitis",
        room_preference: "Private room",
        hospitalization_diagnoses_attributes: {
          "0" => { diagnosis_id: diagnoses(:pneumonia).id },
          "1" => { diagnosis_id: diagnoses(:hypertension).id }
        }
      } }
    end

    assert_redirected_to hospitalization_url(Hospitalization.last)
    assert_equal [ diagnoses(:pneumonia).id, diagnoses(:hypertension).id ].sort, Hospitalization.last.diagnoses.ids.sort
    assert_equal "Pneumonia, Hypertension", Hospitalization.last.diagnosis_names_display
  end

  test "should reject create without any diagnosis" do
    assert_no_difference("Hospitalization.count") do
      post hospitalizations_url, params: { hospitalization: {
        patient_id: patients(:one).id,
        admission_date: "2026-05-01",
        reason: "Acute bronchitis"
      } }
    end

    assert_response :unprocessable_entity
  end

  test "show displays the finalized length of stay for a discharged hospitalization" do
    get hospitalization_url(@hospitalization)
    assert_response :success

    assert_equal "6 days", length_of_stay_field(@response.body)
  end

  test "show displays the running day count for a hospitalization still admitted" do
    travel_to Date.new(2026, 6, 4) do
      get hospitalization_url(hospitalizations(:three))
      assert_response :success

      assert_equal "Day 4 (ongoing)", length_of_stay_field(@response.body)
    end
  end

  test "show displays a dash for a reservation that has not been admitted yet" do
    get hospitalization_url(hospitalizations(:four))
    assert_response :success

    assert_equal "-", length_of_stay_field(@response.body)
  end

  test "edit renders the diagnosis picker frame and turbo-frame links into it" do
    get edit_hospitalization_url(@hospitalization)
    assert_response :success
    assert_select "turbo-frame#diagnosis_picker_frame"
    assert_select "a[data-turbo-frame='diagnosis_picker_frame'][href=?]", picker_diagnoses_path
  end

  test "should update hospitalization" do
    patch hospitalization_url(@hospitalization), params: { hospitalization: {
      patient_id: @hospitalization.patient_id,
      admission_date: @hospitalization.admission_date,
      planned_days: @hospitalization.planned_days,
      reason: @hospitalization.reason,
      hospitalization_diagnoses_attributes: {
        "0" => {
          id: hospitalization_diagnoses(:one_pneumonia).id,
          diagnosis_id: diagnoses(:fracture).id
        },
        "1" => {
          id: hospitalization_diagnoses(:one_hypertension).id,
          diagnosis_id: diagnoses(:appendicitis).id
        }
      }
    } }

    assert_redirected_to hospitalization_url(@hospitalization)
    @hospitalization.reload
    assert_equal [ diagnoses(:fracture).id, diagnoses(:appendicitis).id ].sort, @hospitalization.diagnoses.ids.sort
  end

  test "should record discharge information on update" do
    hospitalization = hospitalizations(:three)

    patch hospitalization_url(hospitalization), params: { hospitalization: {
      patient_id: hospitalization.patient_id,
      admission_date: hospitalization.admission_date,
      reason: hospitalization.reason,
      discharge_date: "2026-06-04",
      outcome: "improved",
      discharge_destination: "home"
    } }

    assert_redirected_to hospitalization_url(hospitalization)
    hospitalization.reload
    assert_equal Date.new(2026, 6, 4), hospitalization.discharge_date
    assert_equal "improved", hospitalization.outcome
    assert_equal "home", hospitalization.discharge_destination
  end

  test "should respond with unprocessable entity when diagnoses are swapped between rows" do
    patch hospitalization_url(@hospitalization), params: { hospitalization: {
      patient_id: @hospitalization.patient_id,
      admission_date: @hospitalization.admission_date,
      reason: @hospitalization.reason,
      hospitalization_diagnoses_attributes: {
        "0" => {
          id: hospitalization_diagnoses(:one_pneumonia).id,
          diagnosis_id: diagnoses(:hypertension).id
        },
        "1" => {
          id: hospitalization_diagnoses(:one_hypertension).id,
          diagnosis_id: diagnoses(:pneumonia).id
        }
      }
    } }

    assert_response :unprocessable_entity
    assert_equal [ diagnoses(:pneumonia).id, diagnoses(:hypertension).id ].sort, @hospitalization.reload.diagnoses.ids.sort
  end

  test "should not mask a unique violation from an unrelated constraint as a diagnosis swap error" do
    unrelated_violation = ActiveRecord::RecordNotUnique.new(
      "SQLite3::ConstraintException: UNIQUE constraint failed: patients.hospital_id"
    )

    Hospitalization.define_method(:update) { |*| raise unrelated_violation }

    assert_raises(ActiveRecord::RecordNotUnique) do
      patch hospitalization_url(@hospitalization), params: { hospitalization: {
        patient_id: @hospitalization.patient_id,
        admission_date: @hospitalization.admission_date,
        reason: @hospitalization.reason
      } }
    end
  ensure
    Hospitalization.remove_method(:update) if Hospitalization.instance_methods(false).include?(:update)
  end

  test "should destroy hospitalization" do
    # destroy is now a logical delete: the row survives, moves out of the
    # default index/API scope, and shows up in the deleted list instead.
    assert_no_difference("Hospitalization.count") do
      delete hospitalization_url(@hospitalization)
    end

    assert_redirected_to hospitalizations_url
    assert @hospitalization.reload.deleted?

    get hospitalizations_url
    assert_no_match(/#{Regexp.escape(@hospitalization.reason)}/, @response.body)

    get deleted_hospitalizations_url
    assert_match(/#{Regexp.escape(@hospitalization.reason)}/, @response.body)
  end

  test "admin can restore a discarded hospitalization" do
    @hospitalization.discard!

    patch restore_hospitalization_url(@hospitalization)

    assert_redirected_to hospitalization_url(@hospitalization)
    assert_not @hospitalization.reload.deleted?
  end

  test "a general user cannot restore a discarded hospitalization" do
    @hospitalization.discard!
    sign_out
    sign_in_as(users(:member))

    patch restore_hospitalization_url(@hospitalization)

    assert_redirected_to root_url
    assert @hospitalization.reload.deleted?
  end

  test "a general user cannot view the deleted list" do
    sign_out
    sign_in_as(users(:member))

    get deleted_hospitalizations_url

    assert_redirected_to root_url
  end

  test "deleted list paginates results" do
    @hospitalization.discard!

    get deleted_hospitalizations_url, params: { page: 1 }

    assert_response :success
  end

  test "deleted list does not error out on a crafted Array page param" do
    @hospitalization.discard!

    get deleted_hospitalizations_url, params: { page: [ "1" ] }

    assert_response :success
  end

  test "deleted list shows the deletion time and a restore action" do
    @hospitalization.discard!

    get deleted_hospitalizations_url

    assert_response :success
    assert_match(/Restore/, @response.body)
    assert_match(/#{@hospitalization.deleted_at.strftime("%Y-%m-%d")}/, @response.body)
  end

  test "admin can copy a hospitalization to a new scheduled admission date" do
    hospitalization = hospitalizations(:two)

    assert_difference("Hospitalization.count", 1) do
      post copy_hospitalization_url(hospitalization), params: { scheduled_admission_date: "2027-02-01" }
    end

    copy = Hospitalization.order(:id).last
    assert_redirected_to edit_hospitalization_url(copy)
    assert_equal Date.new(2027, 2, 1), copy.scheduled_admission_date
    assert_equal "requested", copy.reservation_status
    assert_equal "unconfirmed", copy.admin_status
  end

  test "copy with a blank date does not save and redirects back to the original" do
    hospitalization = hospitalizations(:two)

    assert_no_difference("Hospitalization.count") do
      post copy_hospitalization_url(hospitalization), params: { scheduled_admission_date: "" }
    end

    assert_redirected_to hospitalization_url(hospitalization)
  end

  test "a general user cannot copy a hospitalization" do
    hospitalization = hospitalizations(:two)
    sign_out
    sign_in_as(users(:member))

    assert_no_difference("Hospitalization.count") do
      post copy_hospitalization_url(hospitalization), params: { scheduled_admission_date: "2027-02-01" }
    end

    assert_redirected_to root_url
  end

  test "a general user update resets admin_status to unconfirmed" do
    @hospitalization.update!(admin_status: "confirmed")
    sign_out
    sign_in_as(users(:member))

    patch hospitalization_url(@hospitalization), params: { hospitalization: {
      patient_id: @hospitalization.patient_id,
      admission_date: @hospitalization.admission_date,
      reason: @hospitalization.reason
    } }

    assert_redirected_to hospitalization_url(@hospitalization)
    assert_equal "unconfirmed", @hospitalization.reload.admin_status
  end

  test "an admin update does not reset admin_status" do
    @hospitalization.update!(admin_status: "confirmed")

    patch hospitalization_url(@hospitalization), params: { hospitalization: {
      patient_id: @hospitalization.patient_id,
      admission_date: @hospitalization.admission_date,
      reason: @hospitalization.reason
    } }

    assert_redirected_to hospitalization_url(@hospitalization)
    assert_equal "confirmed", @hospitalization.reload.admin_status
  end

  test "a general user cannot set admin_status directly through params" do
    sign_out
    sign_in_as(users(:member))

    patch hospitalization_url(@hospitalization), params: { hospitalization: {
      patient_id: @hospitalization.patient_id,
      admission_date: @hospitalization.admission_date,
      reason: @hospitalization.reason,
      admin_status: "confirmed"
    } }

    assert_equal "unconfirmed", @hospitalization.reload.admin_status
  end

  test "admin can confirm a hospitalization" do
    patch confirm_hospitalization_url(@hospitalization)

    assert_redirected_to hospitalization_url(@hospitalization)
    assert_equal "confirmed", @hospitalization.reload.admin_status
  end

  test "a general user cannot confirm a hospitalization" do
    sign_out
    sign_in_as(users(:member))

    patch confirm_hospitalization_url(@hospitalization)

    assert_redirected_to root_url
    assert_equal "unconfirmed", @hospitalization.reload.admin_status
  end

  test "should get new with the three form sections" do
    get new_hospitalization_url

    assert_response :success
    assert_select "h2", text: "Patient & Schedule"
    assert_select "h2", text: "Admission & Surgery Details"
    assert_select "h2", text: "Comments"
  end

  test "show renders the diagnosis name, not a raw object, in the update history" do
    @hospitalization.hospitalization_diagnoses.create!(diagnosis: diagnoses(:fracture))

    get hospitalization_url(@hospitalization)

    assert_response :success
    assert_match(/Fracture/, @response.body)
    assert_no_match(/#&lt;Diagnosis/, @response.body)
  end

  test "show displays only this hospitalization's own update history" do
    @hospitalization.update!(room_preference: "History target room")
    hospitalizations(:two).update!(room_preference: "Other hospitalization room")

    get hospitalization_url(@hospitalization)

    assert_response :success
    assert_match(/History target room/, @response.body)
    assert_no_match(/Other hospitalization room/, @response.body)
  end

  test "show does not issue more queries as more audit events exist for the hospitalization" do
    patient_a = Patient.create!(hospital_id: "H920", name: "Audit Patient A", date_of_birth: "1970-01-01")
    patient_b = Patient.create!(hospital_id: "H921", name: "Audit Patient B", date_of_birth: "1970-01-01")

    one_update_hospitalization = Hospitalization.create!(
      patient: patient_a,
      admission_date: Date.new(2027, 6, 1),
      discharge_date: Date.new(2027, 6, 10),
      outcome: "recovered",
      reason: "Observation",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ]
    )
    one_update_hospitalization.update!(room_preference: "First update")

    many_updates_hospitalization = Hospitalization.create!(
      patient: patient_b,
      admission_date: Date.new(2027, 7, 1),
      discharge_date: Date.new(2027, 7, 10),
      outcome: "recovered",
      reason: "Observation",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ]
    )
    5.times { |n| many_updates_hospitalization.update!(room_preference: "Update #{n}") }

    one_update_queries = count_sql_queries { get hospitalization_url(one_update_hospitalization) }
    assert_response :success

    many_updates_queries = count_sql_queries { get hospitalization_url(many_updates_hospitalization) }
    assert_response :success

    assert_equal one_update_queries, many_updates_queries
  end

  private

    # Reads the Length of Stay value from the index table for the row whose
    # Reason (the secondary line of the diagnoses cell) matches `reason`.
    # Looks up the column by the header's label rather than a hardcoded
    # position, so reordering the table's columns doesn't silently break this
    # helper. The cell stacks the value (primary) over the planned days.
    def length_of_stay_cell_for(html, reason)
      doc = Nokogiri::HTML(html)
      headers = doc.css("table thead th").map { |th| th.css("span").map { |s| s.text.strip } }
      column_index = headers.index { |labels| labels.include?("Length of Stay") }

      row = doc.css("table tbody tr").find { |tr| tr.css("td .ledger-secondary").any? { |el| el.text.strip == reason } }
      row.css("td")[column_index].at_css(".ledger-primary").text.strip
    end

    # Reads the Length of Stay value from the show page's field grid, found
    # by its label text rather than a hardcoded position in the markup.
    def length_of_stay_field(html)
      doc = Nokogiri::HTML(html)
      label = doc.css("span").find { |span| span.text.strip == "Length of Stay" }
      label.parent.css("span:last-child").text.strip
    end

    def count_sql_queries
      count = 0
      callback = ->(*, payload) { count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
      count
    end

  test "new form hides the reason field unless the purpose is other" do
    get new_hospitalization_url
    assert_response :success

    assert_select "[data-purpose-fields-target='otherSection'].hidden textarea#hospitalization_reason"
    assert_select "[data-purpose-fields-target='otherSection'] label", text: /Details \(Reason for Admission\)/
  end

  test "edit form shows the reason field when the purpose is other" do
    @hospitalization.update_columns(purpose: "other", reason: "Social admission")

    get edit_hospitalization_url(@hospitalization)
    assert_response :success

    assert_select "[data-purpose-fields-target='otherSection']:not(.hidden) textarea#hospitalization_reason", text: /Social admission/
  end

  test "new form marks required fields and explains the marker" do
    get new_hospitalization_url
    assert_response :success

    assert_select "p", text: /Required/
    %w[hospitalization_reservation_status hospitalization_purpose hospitalization_scheduled_admission_date].each do |id|
      assert_select "label.app-field-label-required[for=#{id}]"
    end
    assert_select ".app-field-label-required", text: "Diagnoses at Admission"
    assert_select ".app-field-label-required", text: "Patient"
    assert_select "label.app-field-label-required[for=hospitalization_reason]"
  end

  test "creates a surgery hospitalization without a reason" do
    patient = Patient.create!(name: "No Reason Patient", hospital_id: "NR1", date_of_birth: Date.new(1980, 1, 1))
    assert_difference("Hospitalization.count", 1) do
      post hospitalizations_url, params: { hospitalization: {
        patient_id: patient.id, scheduled_admission_date: "2027-01-10", reservation_status: "requested",
        purpose: "surgery", hospitalization_diagnoses_attributes: { "0" => { diagnosis_id: diagnoses(:appendicitis).id } }
      } }
    end
  end

  test "new prefills the scheduled surgery date and purpose from params" do
    get new_hospitalization_url(scheduled_surgery_date: "2027-03-04", purpose: "surgery")
    assert_response :success

    assert_select "input#hospitalization_scheduled_surgery_date[value=?]", "2027-03-04"
    assert_select "select#hospitalization_purpose option[selected][value=?]", "surgery"
    assert_select "input#hospitalization_scheduled_admission_date:not([value])"
  end

  test "new ignores an unknown purpose param" do
    get new_hospitalization_url(purpose: "bogus")
    assert_response :success

    assert_select "select#hospitalization_purpose option[selected][value=?]", "surgery"
  end

  test "creating a surgery hospitalization with a scheduled surgery date continues to the new surgery form" do
    patient = Patient.create!(name: "Follow Up Patient", hospital_id: "FU1", date_of_birth: Date.new(1980, 1, 1))

    post hospitalizations_url, params: { hospitalization: {
      patient_id: patient.id, scheduled_admission_date: "2027-03-03", scheduled_surgery_date: "2027-03-04",
      reservation_status: "requested", purpose: "surgery",
      hospitalization_diagnoses_attributes: { "0" => { diagnosis_id: diagnoses(:appendicitis).id } }
    } }

    assert_redirected_to new_surgery_url(patient_id: patient.id, surgery_date: "2027-03-04")
    assert_equal "Hospitalization was successfully created. Now register the surgery.", flash[:notice]
  end

  test "creating a non-surgery hospitalization redirects to it as before" do
    patient = Patient.create!(name: "Exam Patient", hospital_id: "EX1", date_of_birth: Date.new(1980, 1, 1))

    post hospitalizations_url, params: { hospitalization: {
      patient_id: patient.id, scheduled_admission_date: "2027-03-03", scheduled_surgery_date: "2027-03-04",
      reservation_status: "requested", purpose: "examination",
      hospitalization_diagnoses_attributes: { "0" => { diagnosis_id: diagnoses(:appendicitis).id } }
    } }

    assert_redirected_to hospitalization_url(Hospitalization.order(:id).last)
  end

  test "show displays the scheduled surgery date" do
    @hospitalization.update_columns(scheduled_surgery_date: Date.new(2026, 3, 2))

    get hospitalization_url(@hospitalization)
    assert_response :success
    assert_select "span", text: /Scheduled Surgery Date/
    assert_match "2026", @response.body
  end

  test "show displays the purpose name when purpose is not other even if reason is present" do
    @hospitalization.update_columns(purpose: "surgery", reason: "Previous reason")

    get hospitalization_url(@hospitalization)
    assert_response :success

    assert_select "h2.card-title", text: "Surgery"
  end

  test "show displays the reason as heading when purpose is other" do
    @hospitalization.update_columns(purpose: "other", reason: "Social admission")

    get hospitalization_url(@hospitalization)
    assert_response :success

    assert_select "h2.card-title", text: "Social admission"
  end

  private

    def hospitalization_ids_in_table
      css_select("table.app-ledger td.ledger-actions a[href^='/hospitalizations/']").filter_map do |a|
        a["href"][%r{\A/hospitalizations/(\d+)\z}, 1]&.to_i
      end.uniq
    end
end
