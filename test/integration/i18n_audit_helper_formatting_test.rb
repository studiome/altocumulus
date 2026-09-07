require "test_helper"

# Cross-cutting i18n gap: three remaining raw `strftime` call sites
# (replaced with `I18n.l`) and two hardcoded strings in AuditEventsHelper
# (the "-" blank placeholder and the "(not found)" foreign-key suffix).
class I18nAuditHelperFormattingTest < ActionDispatch::IntegrationTest
  setup { sign_out }

  # ---------------------------------------------------------------------
  # strftime -> I18n.l
  # ---------------------------------------------------------------------

  test "audit log date/time changes render with the locale's date and timestamp formats" do
    event = AuditEvent.create!(
      auditable_type: "Patient", auditable_id: patients(:one).id,
      action: "update", record_label: patients(:one).to_s,
      change_data: {
        "date_of_birth" => [ "1990-01-01", "1991-02-03" ],
        "created_at" => [ "2026-01-02 03:04:05", "2026-02-03 04:05:06" ]
      }
    )

    sign_in_as(users(:japanese_admin))

    get audit_event_url(event)
    assert_match "1990年01月01日", response.body
    assert_match "1991年02月03日", response.body

    sign_out
    sign_in_as(users(:admin))

    get audit_event_url(event)
    assert_match "1990-01-01", response.body
    assert_match "1991-02-03", response.body
  end

  test "surgery date display uses the locale's date format" do
    sign_in_as(users(:japanese_admin))

    get search_url, params: { keyword: "John" }
    assert_match "2026年03月01日", response.body

    get surgery_url(surgeries(:one))
    assert_match "2026年03月01日", response.body

    sign_out
    sign_in_as(users(:admin))

    get surgery_url(surgeries(:one))
    assert_match "2026-03-01", response.body
  end

  # ---------------------------------------------------------------------
  # AuditEventsHelper hardcoded strings
  # ---------------------------------------------------------------------

  test "an unresolved foreign key change renders the localized not-found suffix" do
    surgery = surgeries(:one)
    event = AuditEvent.create!(
      auditable_type: "Surgery", auditable_id: surgery.id,
      action: "update", record_label: surgery.to_s,
      change_data: { "hospitalization_id" => [ nil, 999_999 ] }
    )

    sign_in_as(users(:japanese_admin))

    get audit_event_url(event)
    assert_match(/#999999\s*\(見つかりません\)/, response.body)

    sign_out
    sign_in_as(users(:admin))

    get audit_event_url(event)
    assert_match(/#999999\s*\(not found\)/, response.body)
  end
end
