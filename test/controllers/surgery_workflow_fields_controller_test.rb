require "test_helper"

class SurgeryWorkflowFieldsControllerTest < ActionDispatch::IntegrationTest
  def surgery_params(**extra)
    { patient_id: patients(:one).id, surgery_date: "2026-03-05", anesthesia_method: "General",
      surgery_procedure_selections_attributes: { "0" => { surgery_procedure_id: surgery_procedures(:appendectomy).id } } }.merge(extra)
  end

  test "creating a hospitalization for surgery redirects to a new surgery linked to it" do
    post hospitalizations_url, params: { hospitalization: {
      patient_id: patients(:two).id, scheduled_admission_date: "2027-02-01", scheduled_surgery_date: "2027-02-03",
      purpose: "surgery", hospitalization_diagnoses_attributes: { "0" => { diagnosis_id: diagnoses(:pneumonia).id } }
    } }

    hospitalization = Hospitalization.order(:id).last
    assert_redirected_to new_surgery_url(patient_id: patients(:two).id, surgery_date: "2027-02-03", hospitalization_id: hospitalization.id)
  end

  test "new surgery carries a valid hospitalization_id as a hidden field" do
    hospitalization = hospitalizations(:one)
    get new_surgery_url(patient_id: hospitalization.patient_id, hospitalization_id: hospitalization.id)
    assert_response :success
    assert_select "input[type=hidden][name='surgery[hospitalization_id]'][value='#{hospitalization.id}']"
  end

  test "new surgery ignores a hospitalization that is another patient's, discarded or unknown" do
    [ hospitalizations(:two).id, 0 ].each do |id|
      get new_surgery_url(patient_id: patients(:one).id, hospitalization_id: id)
      assert_select "input[name='surgery[hospitalization_id]'][value]:not([value=''])", count: 0
    end
    hospitalizations(:one).discard!
    get new_surgery_url(patient_id: patients(:one).id, hospitalization_id: hospitalizations(:one).id)
    assert_select "input[name='surgery[hospitalization_id]'][value]:not([value=''])", count: 0
  end

  test "create stores the hospitalization link, backup intervention and performing department" do
    assert_difference("Surgery.count") do
      post surgeries_url, params: { surgery: surgery_params(
        hospitalization_id: hospitalizations(:one).id, slot_category: "backup", backup_intervention: "involved",
        performing_department_id: departments(:gynecology).id
      ) }
    end
    surgery = Surgery.order(:id).last
    assert_equal hospitalizations(:one), surgery.hospitalization
    assert_equal "involved", surgery.backup_intervention
    assert_equal departments(:gynecology), surgery.performing_department
  end

  test "create rejects another patient's hospitalization and a backup without intervention" do
    assert_no_difference("Surgery.count") do
      post surgeries_url, params: { surgery: surgery_params(hospitalization_id: hospitalizations(:two).id) }
    end
    assert_response :unprocessable_entity

    assert_no_difference("Surgery.count") do
      post surgeries_url, params: { surgery: surgery_params(slot_category: "backup") }
    end
    assert_response :unprocessable_entity
  end

  test "the form offers backup intervention and performing department, and keeps the link on edit" do
    surgery = surgeries(:one)
    surgery.update!(hospitalization: hospitalizations(:one))
    get edit_surgery_url(surgery)
    assert_select "input[type=radio][name='surgery[backup_intervention]']", count: 2
    assert_select "select[name='surgery[performing_department_id]']"
    assert_select "input[type=hidden][name='surgery[hospitalization_id]'][value='#{hospitalizations(:one).id}']"
  end

  test "show and json expose the new fields" do
    surgery = surgeries(:one)
    surgery.update!(hospitalization: hospitalizations(:one), slot_category: "backup", backup_intervention: "not_involved",
                    performing_department: departments(:gynecology))
    get surgery_url(surgery)
    assert_select "body", text: /No intervention/
    assert_select "body", text: /Gynecology/
    assert_select "a[href=?]", hospitalization_path(hospitalizations(:one))

    get surgery_url(surgery, format: :json)
    json = JSON.parse(response.body)
    assert_equal hospitalizations(:one).id, json["hospitalization_id"]
    assert_equal "not_involved", json["backup_intervention"]
    assert_equal departments(:gynecology).id, json["performing_department_id"]
    assert_equal "Gynecology", json["performing_department"]
  end

  test "surgery locations can be flagged as asking for a performing department" do
    location = surgery_locations(:cath_lab)
    patch surgery_location_url(location), params: { surgery_location: { asks_performing_department: "1" } }
    assert location.reload.asks_performing_department

    get surgery_locations_url
    assert_select "tr", text: /Cath Lab.*Asks performing department/m

    get edit_surgery_location_url(location)
    assert_select "input[type=checkbox][name='surgery_location[asks_performing_department]'][checked]"

    get edit_department_url(departments(:gynecology))
    assert_select "input[name='department[asks_performing_department]']", count: 0
  end
end
