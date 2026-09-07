require "test_helper"

# Stage 3 (view text externalization), group 4a: the AuditEvents screens
# (index/show), including the shared `common.field_header` /
# `common.before_header` / `common.after_header` keys now reused by
# hospitalizations/show.html.erb's own update-history table (see the design
# note added to hospitalizations' locale block for why they were
# consolidated).
class AuditEventsI18nTest < ActionDispatch::IntegrationTest
  setup do
    sign_out

    @patient_event = AuditEvent.create!(
      auditable_type: "Patient",
      auditable_id: patients(:one).id,
      action: "update",
      record_label: patients(:one).to_s,
      change_data: { "name" => [ "Old name", patients(:one).name ] }
    )
  end

  test "no translation missing on audit event screens rendered in Japanese" do
    sign_in_as(users(:japanese_member))

    [ audit_events_url, audit_event_url(@patient_event) ].each do |url|
      get url
      assert_response :success, "expected #{url} to render successfully in ja"
      assert_no_match(/[Tt]ranslation missing/, response.body, "translation missing while rendering #{url}")
    end
  end

  test "index and show render in Japanese" do
    sign_in_as(users(:japanese_member))

    get audit_events_url
    assert_select "h1", text: "監査ログ"
    assert_select "th", text: "操作者"
    assert_select "a", text: "詳細"

    get audit_event_url(@patient_event)
    assert_select "a", text: "戻る"
    assert_select "th", text: "項目"
    assert_select "th", text: "変更前"
    assert_select "th", text: "変更後"
  end

  test "index and show render unchanged in English" do
    sign_in_as(users(:member))

    get audit_events_url
    assert_select "h1", text: "Audit Log"
    assert_select "th", text: "Operator"
    assert_select "a", text: "View"

    get audit_event_url(@patient_event)
    assert_select "a", text: "Back"
    assert_select "th", text: "Field"
    assert_select "th", text: "Before"
    assert_select "th", text: "After"
  end

  test "audit event timestamps use the Japanese timestamp format" do
    sign_in_as(users(:japanese_member))

    get audit_event_url(@patient_event)
    assert_match(/\d{4}年\d{2}月\d{2}日 \d{2}:\d{2}:\d{2}/, response.body)
  end

  test "audit event timestamps render unchanged in English" do
    sign_in_as(users(:member))

    get audit_event_url(@patient_event)
    assert_match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/, response.body)
  end

  test "pagination controls render in Japanese" do
    sign_in_as(users(:japanese_member))

    (Pagination::DEFAULT_PER_PAGE + 1).times do |index|
      AuditEvent.create!(
        auditable_type: "Patient", auditable_id: patients(:one).id,
        action: "update", record_label: "Bulk #{index}"
      )
    end

    get audit_events_url
    assert_no_match(/[Tt]ranslation missing/, response.body)
    assert_select "a", text: "次へ"
    assert_match(/1 \/ 2 ページ/, response.body)
  end

  test "pagination controls render unchanged in English" do
    sign_in_as(users(:member))

    (Pagination::DEFAULT_PER_PAGE + 1).times do |index|
      AuditEvent.create!(
        auditable_type: "Patient", auditable_id: patients(:one).id,
        action: "update", record_label: "Bulk #{index}"
      )
    end

    get audit_events_url
    assert_select "a", text: "Next"
    assert_select "span", text: /Page 1 of 2/
  end
end
