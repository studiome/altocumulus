require "test_helper"
require "csv"
require_relative "i18n_integration_helper"

# i18n of the AuditEvents screens (index/show/csv), including the
# AuditEventsHelper formatting (locale date formats, "(not found)" suffix) and
# the localized labels of the stored English record types / actions. The
# shared `common.field_header` / `before_header` / `after_header` keys are also
# reused by hospitalizations/show.html.erb's update-history table.
class AuditEventsI18nTest < ActionDispatch::IntegrationTest
  include I18nIntegrationHelper

  setup do
    @patient_event = AuditEvent.create!(
      auditable_type: "Patient",
      auditable_id: patients(:one).id,
      action: "update",
      record_label: patients(:one).to_s,
      change_data: { "name" => [ "Old name", patients(:one).name ] }
    )
  end

  test "index and show render in Japanese and English" do
    get_as users(:japanese_member), audit_events_url
    assert_select "h1", text: "監査ログ"
    assert_select "th", text: "操作者"
    assert_select "a", text: "詳細"

    get audit_event_url(@patient_event)
    assert_select "a", text: "戻る"
    assert_select "th", text: "項目"
    assert_select "th", text: "変更前"
    assert_select "th", text: "変更後"
    assert_match(/\d{4}年\d{2}月\d{2}日 \d{2}:\d{2}:\d{2}/, response.body)

    get_as users(:member), audit_events_url
    assert_select "h1", text: "Audit Log"
    assert_select "th", text: "Operator"
    assert_select "a", text: "View"

    get audit_event_url(@patient_event)
    assert_select "a", text: "Back"
    assert_select "th", text: "Field"
    assert_select "th", text: "Before"
    assert_select "th", text: "After"
    assert_match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/, response.body)
  end

  test "pagination controls render in Japanese and English" do
    (Pagination::DEFAULT_PER_PAGE + 1).times do |index|
      AuditEvent.create!(
        auditable_type: "Patient", auditable_id: patients(:one).id,
        action: "update", record_label: "Bulk #{index}"
      )
    end

    get_as users(:japanese_member), audit_events_url
    assert_select "a", text: "次へ"
    assert_match(/1 \/ 2 ページ/, response.body)

    get_as users(:member), audit_events_url
    assert_select "a", text: "Next"
    assert_select "span", text: /Page 1 of 2/
  end

  test "csv export header row is Japanese and English" do
    get_as users(:japanese_member), audit_events_url(format: :csv)
    assert_response :success
    rows = CSV.parse(response.body.delete_prefix("\xEF\xBB\xBF"))
    assert_equal [ "日時", "対象種別", "対象ID", "操作", "対象", "操作者", "IPアドレス", "変更内容" ], rows.first

    get_as users(:member), audit_events_url(format: :csv)
    assert_response :success
    rows = CSV.parse(response.body.delete_prefix("\xEF\xBB\xBF"))
    assert_equal [ "Time", "Record type", "Record ID", "Action", "Record", "Operator", "IP Address", "Changes" ], rows.first
  end

  test "date/time changes render with the locale's date and timestamp formats" do
    event = AuditEvent.create!(
      auditable_type: "Patient", auditable_id: patients(:one).id,
      action: "update", record_label: patients(:one).to_s,
      change_data: {
        "date_of_birth" => [ "1990-01-01", "1991-02-03" ],
        "created_at" => [ "2026-01-02 03:04:05", "2026-02-03 04:05:06" ]
      }
    )

    get_as users(:japanese_admin), audit_event_url(event)
    assert_match "1990年01月01日", response.body
    assert_match "1991年02月03日", response.body

    get_as users(:admin), audit_event_url(event)
    assert_match "1990-01-01", response.body
    assert_match "1991-02-03", response.body
  end

  test "an unresolved foreign key change renders the localized not-found suffix" do
    surgery = surgeries(:one)
    event = AuditEvent.create!(
      auditable_type: "Surgery", auditable_id: surgery.id,
      action: "update", record_label: surgery.to_s,
      change_data: { "hospitalization_id" => [ nil, 999_999 ] }
    )

    get_as users(:japanese_admin), audit_event_url(event)
    assert_match(/#999999\s*\(見つかりません\)/, response.body)

    get_as users(:admin), audit_event_url(event)
    assert_match(/#999999\s*\(not found\)/, response.body)
  end

  test "record type renders as the localized model name while the stored value stays English" do
    get_as users(:japanese_admin), audit_events_url
    assert_match "患者", response.body

    get audit_event_url(@patient_event)
    assert_select "dd", text: "患者"

    get audit_events_url(auditable_type: "Patient")
    assert_response :success
    assert_select "select#auditable_type option[value=Patient]", text: "患者"
    assert_select "select#auditable_type option[value=Surgery]", text: "手術"
    assert_select "select#auditable_type option[value=Hospitalization]", text: "入院"

    get_as users(:admin), audit_event_url(@patient_event)
    assert_select "dd", text: "Patient"

    assert_equal "Patient", @patient_event.reload.auditable_type
  end

  test "action renders localized on the index badge, show badge, and hospitalization history while the stored value stays English" do
    event = AuditEvent.create!(
      auditable_type: "Hospitalization", auditable_id: hospitalizations(:one).id,
      action: "update", record_label: hospitalizations(:one).to_s,
      change_data: { "reason" => [ "Old reason", hospitalizations(:one).reason ] }
    )

    get_as users(:japanese_admin), audit_events_url
    assert_select "span.badge", text: "更新"

    get audit_event_url(event)
    assert_select "span.badge", text: "更新"

    get hospitalization_url(hospitalizations(:one))
    assert_select "span.badge", text: "更新"

    get audit_events_url(audit_action: "create")
    assert_select "select#audit_action option[value=create]", text: "作成"
    assert_select "select#audit_action option[value=update]", text: "更新"
    assert_select "select#audit_action option[value=destroy]", text: "削除"

    get_as users(:admin), audit_event_url(event)
    assert_select "span.badge", text: "Update"

    assert_equal "update", event.reload.action
  end
end
