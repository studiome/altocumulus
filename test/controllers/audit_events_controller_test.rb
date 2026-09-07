require "test_helper"

class AuditEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @patient_event = AuditEvent.create!(
      auditable_type: "Patient",
      auditable_id: patients(:one).id,
      action: "update",
      record_label: patients(:one).to_s,
      change_data: { "name" => [ "Old name", patients(:one).name ] }
    )
    @surgery_event = AuditEvent.create!(
      auditable_type: "Surgery",
      auditable_id: surgeries(:one).id,
      action: "create",
      record_label: "Surgery record"
    )
  end

  test "index lists audit events newest first" do
    get audit_events_url

    assert_response :success
    assert_select "tbody tr:first-child", text: /Surgery record/
    assert_select "a[href='#{audit_event_path(@patient_event)}']"
  end

  test "index filters by auditable type" do
    get audit_events_url, params: { auditable_type: "Patient" }

    assert_response :success
    assert_match patients(:one).to_s, response.body
    assert_no_match "Surgery record", response.body
  end

  test "index filters by action independently of the auditable type" do
    other_patient_event = AuditEvent.create!(
      auditable_type: "Patient",
      auditable_id: patients(:one).id,
      action: "destroy",
      record_label: "Destroyed patient record"
    )

    get audit_events_url, params: { audit_action: "destroy" }

    assert_response :success
    assert_match other_patient_event.record_label, response.body
    assert_no_match @patient_event.record_label, response.body
    assert_no_match "Surgery record", response.body
  end

  test "index keeps filters on pagination links without breaking url generation" do
    (Pagination::DEFAULT_PER_PAGE + 1).times do |index|
      AuditEvent.create!(
        auditable_type: "Patient",
        auditable_id: index + 1,
        action: "destroy",
        record_label: "Bulk destroyed #{index}"
      )
    end

    get audit_events_url, params: { auditable_type: "Patient", audit_action: "destroy" }

    assert_response :success
    assert_select "a[href*='page=2'][href*='audit_action=destroy'][href*='auditable_type=Patient']"
  end

  test "show displays before and after values" do
    get audit_event_url(@patient_event)

    assert_response :success
    assert_match "Old name", response.body
    assert_match patients(:one).name, response.body
  end

  test "index displays the operator name" do
    AuditEvent.create!(
      auditable_type: "Patient", auditable_id: patients(:one).id, action: "update",
      record_label: "Attributed edit", user: users(:admin)
    )

    get audit_events_url

    assert_response :success
    assert_match users(:admin).name, response.body
  end

  test "index filters by operator" do
    AuditEvent.create!(
      auditable_type: "Patient", auditable_id: patients(:one).id, action: "update",
      record_label: "Admin edit", user: users(:admin)
    )
    AuditEvent.create!(
      auditable_type: "Patient", auditable_id: patients(:one).id, action: "update",
      record_label: "Member edit", user: users(:member)
    )

    get audit_events_url, params: { user_id: users(:member).id }

    assert_response :success
    assert_match "Member edit", response.body
    assert_no_match "Admin edit", response.body
  end

  test "show renders change data as a human readable table without raw json" do
    event = AuditEvent.create!(
      auditable_type: "Patient",
      auditable_id: patients(:one).id,
      action: "update",
      record_label: patients(:one).to_s,
      change_data: { "date_of_birth" => [ "1990-01-01", "1991-02-03" ] }
    )

    get audit_event_url(event)

    assert_response :success
    assert_match "Date of birth", response.body
    assert_match "1990-01-01", response.body
    assert_match "1991-02-03", response.body
    assert_no_match(/\{&quot;date_of_birth|\{"date_of_birth"/, response.body)
  end

  test "show resolves foreign key values to their referenced record's label" do
    hospitalization = hospitalizations(:one)
    event = AuditEvent.create!(
      auditable_type: "Surgery",
      auditable_id: surgeries(:one).id,
      action: "update",
      record_label: surgeries(:one).to_s,
      change_data: { "hospitalization_id" => [ nil, hospitalization.id ] }
    )

    get audit_event_url(event)

    assert_response :success
    assert_match hospitalization.to_s, response.body
  end

  test "show resolves an associated surgery_procedure_selection's surgery_procedure_id to its name" do
    surgery = surgeries(:one)
    selection = surgery_procedure_selections(:one_appendectomy)
    event = AuditEvent.create!(
      auditable_type: "Surgery",
      auditable_id: surgery.id,
      action: "update",
      record_label: surgery.to_s,
      change_data: { "surgery_procedure_selection[#{selection.id}].surgery_procedure_id" => [ nil, selection.surgery_procedure_id ] }
    )

    get audit_event_url(event)

    assert_response :success
    assert_match selection.surgery_procedure.name, response.body
    assert_no_match(/SurgeryProcedure:0x/, response.body)
  end

  test "show resolves an associated surgery_diagnosis_link's patient_diagnosis_id to its label" do
    surgery = surgeries(:one)
    link = surgery_diagnosis_links(:one_appendicitis)
    event = AuditEvent.create!(
      auditable_type: "Surgery",
      auditable_id: surgery.id,
      action: "update",
      record_label: surgery.to_s,
      change_data: { "surgery_diagnosis_link[#{link.id}].patient_diagnosis_id" => [ nil, link.patient_diagnosis_id ] }
    )

    get audit_event_url(event)

    assert_response :success
    assert_match link.patient_diagnosis.to_s, response.body
    assert_no_match(/PatientDiagnosis:0x/, response.body)
  end

  test "only read routes exist" do
    post audit_events_url
    assert_response :not_found

    patch audit_event_url(@patient_event)
    assert_response :not_found

    delete audit_event_url(@patient_event)
    assert_response :not_found
  end
end
