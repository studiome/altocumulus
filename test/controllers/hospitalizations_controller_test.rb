require "test_helper"

class HospitalizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @hospitalization = hospitalizations(:one)
  end

  test "should get index" do
    get hospitalizations_url
    assert_response :success
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

  test "index paginates results" do
    get hospitalizations_url, params: { page: 1 }
    assert_response :success
  end

  test "index filters by status upcoming" do
    patient = Patient.create!(hospital_id: "H910", name: "Future Patient", date_of_birth: "1980-01-01")
    Hospitalization.create!(
      patient: patient,
      scheduled_admission_date: 30.days.from_now.to_date,
      reason: "Upcoming filter target",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ]
    )

    get hospitalizations_url, params: { status: "upcoming" }

    assert_response :success
    assert_match(/Upcoming filter target/, @response.body)
    assert_no_match(/Community-acquired pneumonia/, @response.body)
  end

  test "index filters by status waiting" do
    @hospitalization.update!(reservation_status: "waiting")
    hospitalizations(:two).update!(reservation_status: "admitted")

    get hospitalizations_url, params: { status: "waiting" }

    assert_response :success
    assert_match(/#{Regexp.escape(@hospitalization.reason)}/, @response.body)
    assert_no_match(/Post-surgical observation/, @response.body)
  end

  test "index filters by status unconfirmed" do
    hospitalizations(:two).update!(admin_status: "confirmed")

    get hospitalizations_url, params: { status: "unconfirmed" }

    assert_response :success
    assert_match(/#{Regexp.escape(@hospitalization.reason)}/, @response.body)
    assert_no_match(/Post-surgical observation/, @response.body)
  end

  test "index filters by status recently_updated" do
    hospitalizations(:two).update_column(:updated_at, 5.days.ago)

    get hospitalizations_url, params: { status: "recently_updated" }

    assert_response :success
    assert_match(/#{Regexp.escape(@hospitalization.reason)}/, @response.body)
    assert_no_match(/Post-surgical observation/, @response.body)
  end

  test "index filters by status referred" do
    @hospitalization.update!(referred_from: "General Clinic")

    get hospitalizations_url, params: { status: "referred" }

    assert_response :success
    assert_match(/#{Regexp.escape(@hospitalization.reason)}/, @response.body)
    assert_no_match(/Post-surgical observation/, @response.body)
  end

  test "index shows reservation status, purpose, and admin confirmation state" do
    get hospitalizations_url
    assert_response :success
    assert_match(/Requested|Waiting for Admission|Admission Date Fixed/, @response.body)
    assert_match(/Unconfirmed|Confirmed/, @response.body)
  end

  test "index orders reservation-only hospitalizations by scheduled_admission_date" do
    reservation = Hospitalization.create!(
      patient: patients(:two),
      scheduled_admission_date: Date.new(2027, 1, 1),
      reason: "Planned surgery",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ]
    )

    get hospitalizations_url
    assert_response :success

    body_index = @response.body.index(reservation.reason)
    other_index = @response.body.index(hospitalizations(:three).reason)
    assert body_index < other_index, "expected the furthest-out scheduled hospitalization to sort first"
  end

  test "should get new" do
    get new_hospitalization_url
    assert_response :success
  end

  test "new renders the diagnosis modal frame and turbo-frame New Diagnosis links" do
    get new_hospitalization_url
    assert_response :success
    assert_select "turbo-frame#diagnosis_modal_frame"
    assert_select "a[data-turbo-frame='diagnosis_modal_frame']", text: "New Diagnosis"
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
    assert_equal "Pneumonia、Hypertension", Hospitalization.last.diagnosis_names_display
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

  test "should show hospitalization" do
    get hospitalization_url(@hospitalization)
    assert_response :success
  end

  test "should get edit" do
    get edit_hospitalization_url(@hospitalization)
    assert_response :success
  end

  test "edit renders the diagnosis modal frame and turbo-frame New Diagnosis links" do
    get edit_hospitalization_url(@hospitalization)
    assert_response :success
    assert_select "turbo-frame#diagnosis_modal_frame"
    assert_select "a[data-turbo-frame='diagnosis_modal_frame']", text: "New Diagnosis"
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

  test "should reject reassigning the patient while a surgery is linked" do
    other_patient = Patient.create!(hospital_id: "H999", name: "Unrelated Patient", date_of_birth: "1975-01-01")
    surgery = Surgery.create!(
      patient: patients(:one),
      hospitalization: @hospitalization,
      surgery_date: Date.new(2026, 3, 3),
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    patch hospitalization_url(@hospitalization), params: { hospitalization: {
      patient_id: other_patient.id,
      admission_date: @hospitalization.admission_date,
      planned_days: @hospitalization.planned_days,
      reason: @hospitalization.reason
    } }

    assert_response :unprocessable_entity
    surgery.reload
    assert_equal patients(:one).id, surgery.patient_id
    assert_equal @hospitalization.id, surgery.hospitalization_id
    assert_equal patients(:one).id, @hospitalization.reload.patient_id
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

  test "discarding a hospitalization does not unlink its surgeries" do
    surgery = Surgery.create!(
      patient: patients(:one),
      hospitalization: @hospitalization,
      surgery_date: Date.new(2026, 3, 3),
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    delete hospitalization_url(@hospitalization)

    assert_equal @hospitalization.id, surgery.reload.hospitalization_id
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

  test "show does not issue more queries as more surgeries are linked" do
    patient_a = Patient.create!(hospital_id: "H901", name: "Patient A", date_of_birth: "1970-01-01")
    patient_b = Patient.create!(hospital_id: "H902", name: "Patient B", date_of_birth: "1970-01-01")

    one_surgery_hospitalization = Hospitalization.create!(
      patient: patient_a,
      admission_date: Date.new(2027, 5, 1),
      discharge_date: Date.new(2027, 5, 10),
      outcome: "recovered",
      reason: "Observation",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ]
    )
    Surgery.create!(
      patient: patient_a,
      hospitalization: one_surgery_hospitalization,
      surgery_date: Date.new(2027, 5, 3),
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    three_surgery_hospitalization = Hospitalization.create!(
      patient: patient_b,
      admission_date: Date.new(2027, 5, 1),
      discharge_date: Date.new(2027, 5, 10),
      outcome: "recovered",
      reason: "Observation",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ]
    )
    [ :appendectomy, :cholecystectomy, :knee_arthroscopy ].each do |procedure|
      Surgery.create!(
        patient: patient_b,
        hospitalization: three_surgery_hospitalization,
        surgery_date: Date.new(2027, 5, 3),
        anesthesia_method: "General",
        duration_hours: 1.0,
        surgery_procedure_selections_attributes: [
          { surgery_procedure_id: surgery_procedures(procedure).id, laterality: "right" }
        ]
      )
    end

    one_surgery_queries = count_sql_queries { get hospitalization_url(one_surgery_hospitalization) }
    assert_response :success

    three_surgery_queries = count_sql_queries { get hospitalization_url(three_surgery_hospitalization) }
    assert_response :success

    assert_equal one_surgery_queries, three_surgery_queries
  end

  private

    def count_sql_queries
      count = 0
      callback = ->(*, payload) { count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
      count
    end
end
