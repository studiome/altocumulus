require "test_helper"

class HospitalizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @hospitalization = hospitalizations(:one)
  end

  test "should get index" do
    get hospitalizations_url
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

  test "should get new" do
    get new_hospitalization_url
    assert_response :success
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
    assert_difference("Hospitalization.count", -1) do
      delete hospitalization_url(@hospitalization)
    end

    assert_redirected_to hospitalizations_url
  end
end
