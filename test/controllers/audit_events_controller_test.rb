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

  test "index filters by auditable type and action" do
    get audit_events_url, params: { auditable_type: "Patient", action: "update" }

    assert_response :success
    assert_match patients(:one).to_s, response.body
    assert_no_match "Surgery record", response.body
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
