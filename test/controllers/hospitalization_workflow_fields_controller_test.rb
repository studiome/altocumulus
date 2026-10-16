require "test_helper"

class HospitalizationWorkflowFieldsControllerTest < ActionDispatch::IntegrationTest
  def create_params(**extra)
    { hospitalization: {
      patient_id: patients(:two).id, scheduled_admission_date: "2027-02-01", purpose: "examination", reason: "r",
      hospitalization_diagnoses_attributes: { "0" => { diagnosis_id: diagnoses(:pneumonia).id } }
    }.merge(extra) }
  end

  test "create stores the workflow fields and records the signed-in user as creator" do
    assert_difference("Hospitalization.count") do
      post hospitalizations_url, params: create_params(
        emergency_admission: "1", transfer_status: "transferred_in", source_department_id: departments(:gynecology).id,
        reservation_doctor_id: users(:member).id, scheduled_procedure_date: "2027-02-02", procedure_name: "Colonoscopy"
      )
    end

    record = Hospitalization.order(:id).last
    assert record.emergency_admission
    assert_equal "transferred_in", record.transfer_status
    assert_equal departments(:gynecology), record.source_department
    assert_equal users(:member), record.reservation_doctor
    assert_equal Date.new(2027, 2, 2), record.scheduled_procedure_date
    assert_equal "Colonoscopy", record.procedure_name
    assert_equal users(:admin), record.created_by
  end

  test "created_by cannot be set or changed through params" do
    post hospitalizations_url, params: create_params(created_by_id: users(:member).id)
    record = Hospitalization.order(:id).last
    assert_equal users(:admin), record.created_by

    patch hospitalization_url(record), params: { hospitalization: { created_by_id: users(:member).id, reason: "again" } }
    assert_equal users(:admin), record.reload.created_by
  end

  test "new and edit forms offer every new control" do
    get new_hospitalization_url
    assert_response :success
    assert_select "input[type=checkbox][name='hospitalization[emergency_admission]']"
    assert_select "select[name='hospitalization[transfer_status]'] option", count: 3
    assert_select "select[name='hospitalization[source_department_id]']"
    assert_select "select[name='hospitalization[reservation_doctor_id]']"
    assert_select "input[name='hospitalization[scheduled_procedure_date]']"
    assert_select "input[name='hospitalization[procedure_name]']"
    assert_select "input[name='hospitalization[created_by_id]']", count: 0
  end

  test "reservation doctor select lists active users by name only, keeping the saved one" do
    get new_hospitalization_url
    names = css_select("select[name='hospitalization[reservation_doctor_id]'] option").map(&:text).reject(&:blank?)
    assert_equal User.active.order(:name).pluck(:name), names
    assert_not_includes names, users(:inactive).name

    hospitalizations(:one).update!(reservation_doctor: users(:inactive))
    get edit_hospitalization_url(hospitalizations(:one))
    names = css_select("select[name='hospitalization[reservation_doctor_id]'] option").map(&:text)
    assert_includes names, users(:inactive).name
  end

  test "show displays the new fields and falls back to the legacy reservation doctor" do
    record = hospitalizations(:one)
    record.update!(reservation_doctor_legacy_name: "Dr. Old", emergency_admission: true, transfer_status: "operated_without_transfer",
                   source_department: departments(:gynecology), procedure_name: "Biopsy")
    get hospitalization_url(record)
    assert_select "body", text: /Dr\. Old/
    assert_select "body", text: /Gynecology/
    assert_select "body", text: /Biopsy/

    record.update!(reservation_doctor: users(:member))
    get hospitalization_url(record)
    assert_select "body", text: /Member User/
    assert_select "body", text: /Dr\. Old/, count: 0
  end

  test "json keeps reservation_doctor as the display string and adds the ids" do
    record = hospitalizations(:one)
    record.update!(reservation_doctor_legacy_name: "Dr. Old")
    get hospitalization_url(record, format: :json)
    json = JSON.parse(response.body)
    assert_equal "Dr. Old", json["reservation_doctor"]
    assert_nil json["reservation_doctor_id"]
    assert_equal false, json["emergency_admission"]
    assert_equal "none", json["transfer_status"]
    assert json.key?("created_by_id")

    record.update!(reservation_doctor: users(:member))
    get hospitalization_url(record, format: :json)
    json = JSON.parse(response.body)
    assert_equal "Member User", json["reservation_doctor"]
    assert_equal users(:member).id, json["reservation_doctor_id"]
  end

  test "the form marks purpose-conditional required fields for the current purpose" do
    with_site_config("required_fields" => { "hospitalization_by_purpose" => { "examination" => %w[procedure_name] } }) do
      get new_hospitalization_url(purpose: "examination")
      assert_select "label[for=hospitalization_procedure_name].app-field-label-required", count: 1
      get new_hospitalization_url(purpose: "surgery")
      assert_select "label[for=hospitalization_procedure_name].app-field-label-required", count: 0
      assert_select "label[for=hospitalization_procedure_name][data-required-purposes=examination]", count: 1
    end
  end
end
