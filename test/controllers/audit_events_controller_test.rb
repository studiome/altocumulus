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

  test "only read routes exist" do
    post audit_events_url
    assert_response :not_found

    patch audit_event_url(@patient_event)
    assert_response :not_found

    delete audit_event_url(@patient_event)
    assert_response :not_found
  end
end
