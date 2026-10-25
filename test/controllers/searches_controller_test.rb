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

    get search_url, params: { keyword: "Search Target", tab: "hospitalizations" }
    assert_response :success
    assert_select "table.app-ledger a[href='#{hospitalization_path(hospitalization)}']"

    get search_url, params: { keyword: "Search Target", tab: "surgeries" }
    assert_select "table.app-ledger a[href='#{surgery_path(surgery)}']"

    get search_url, params: { keyword: "Search Target", tab: "patients" }
    assert_select "table a[href='#{patient_path(patient)}']", text: "Search Target Patient"
  end

  test "results are split into hospitalization, surgery and patient tabs with their counts" do
    get search_url, params: { keyword: "John" }

    assert_response :success
    assert_select "[role=tablist] a[role=tab]", 3
    tabs = css_select("[role=tablist] a[role=tab]").map { |tab| tab.text.squish }
    assert_match(/\AHospitalizations \(\d+\)\z/, tabs[0])
    assert_match(/\ASurgeries \(\d+\)\z/, tabs[1])
    assert_equal "Patients (1)", tabs[2]
    assert_select "a[role=tab][aria-selected=true]", text: /Hospitalizations/
    assert_select "[role=tabpanel] table.app-ledger"
  end

  test "only the selected tab's rows are shown" do
    get search_url, params: { keyword: "John", tab: "surgeries" }

    assert_select "a[role=tab][aria-selected=true]", text: /Surgeries/
    assert_select "[role=tabpanel] a[href^='/surgeries/']"
    assert_select "[role=tabpanel] a[href^='/hospitalizations/']", false
    assert_select "a[href=?]", surgeries_path(keyword: "John")
  end

  test "tab links keep the keyword" do
    get search_url, params: { keyword: "John" }

    assert_select "a[role=tab][href=?]", search_path(keyword: "John", tab: "patients")
  end

  test "without a tab, the first tab that has results is opened" do
    Patient.create!(hospital_id: "SRCHP", name: "Lonely Patient Only", date_of_birth: "1980-01-01")

    get search_url, params: { keyword: "Lonely Patient Only" }

    assert_select "a[role=tab][aria-selected=true]", text: /Patients/
    assert_select "[role=tabpanel] a", text: "Lonely Patient Only"
  end

  test "an unknown tab falls back to the default" do
    get search_url, params: { keyword: "John", tab: "bogus" }

    assert_response :success
    assert_select "a[role=tab][aria-selected=true]", text: /Hospitalizations/
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

    %w[hospitalizations surgeries patients].each do |tab|
      small_count = count_queries { get search_url, params: { keyword: "Bounded Query Patient 0", tab: tab } }
      large_count = count_queries { get search_url, params: { keyword: "Bounded Query", tab: tab } }

      assert_equal small_count, large_count, tab
    end
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
