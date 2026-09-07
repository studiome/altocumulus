require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  test "a blank keyword shows the search form without any results" do
    get search_url

    assert_response :success
    assert_select ".app-empty-state", text: /Enter a keyword/
  end

  test "matches patients, hospitalizations, and surgeries by keyword" do
    patient = Patient.create!(hospital_id: "SRCH1", name: "Search Target Patient", date_of_birth: "1980-01-01")
    hospitalization = Hospitalization.create!(
      patient: patient, reason: "Search Target Reason",
      scheduled_admission_date: Date.current + 10,
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:appendicitis).id } ]
    )
    surgery = Surgery.new(
      patient: patient, anesthesia_method: "General",
      surgery_procedure_selections_attributes: [ { surgery_procedure_id: surgery_procedures(:appendectomy).id } ]
    )
    surgery.surgery_date_status = "undecided"
    surgery.save!

    get search_url, params: { keyword: "Search Target" }

    assert_response :success
    assert_select "a[href='#{patient_path(patient)}']", text: "Search Target Patient"
    assert_select "a[href='#{hospitalization_path(hospitalization)}']"
    assert_select "a[href='#{surgery_path(surgery)}']"
  end

  test "does not match unrelated records" do
    Patient.create!(hospital_id: "SRCH2", name: "Unrelated Person", date_of_birth: "1980-01-01")

    get search_url, params: { keyword: "Zzzznomatch" }

    assert_response :success
    assert_no_match(/Unrelated Person/, @response.body)
  end

  test "excludes soft-deleted hospitalizations from results, matching Hospitalization.filtered" do
    patient = Patient.create!(hospital_id: "SRCH3", name: "Deleted Target Patient", date_of_birth: "1980-01-01")
    hospitalization = Hospitalization.create!(
      patient: patient, reason: "Deleted Search Target",
      scheduled_admission_date: Date.current + 10,
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:appendicitis).id } ]
    )
    hospitalization.discard!

    get search_url, params: { keyword: "Deleted Search Target" }

    assert_response :success
    assert_select "a[href='#{hospitalization_path(hospitalization)}']", false
  end

  test "issues a bounded number of queries regardless of how many records match" do
    5.times do |n|
      patient = Patient.create!(hospital_id: "BND#{n}", name: "Bounded Query Patient #{n}", date_of_birth: "1980-01-01")
      Hospitalization.create!(
        patient: patient, reason: "Bounded Query Reason",
        scheduled_admission_date: Date.current + 10 + n,
        hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:appendicitis).id } ]
      )
    end

    small_count = count_queries { get search_url, params: { keyword: "Bounded Query Patient 0" } }
    large_count = count_queries { get search_url, params: { keyword: "Bounded Query" } }

    assert_equal small_count, large_count
  end

  private

    def count_queries
      count = 0
      counter = ->(_name, _started, _finished, _unique_id, payload) do
        count += 1 unless payload[:cached] || payload[:name] == "SCHEMA"
      end

      ActiveRecord::Base.lease_connection.materialize_transactions
      ActiveRecord::Base.uncached do
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
      end
      count
    end
end
