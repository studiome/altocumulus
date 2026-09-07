require "test_helper"

# Cross-cutting i18n gap: three DB-backed constants that stayed as raw
# values instead of following the `*_KEYS` + `*_options` pattern stage 2
# established (see Hospitalization::PURPOSE_KEYS / .purpose_options):
# User::ROLES, AuditEvent::AUDITABLE_TYPES, AuditEvent::ACTIONS. In every
# case the DB column itself keeps its English key; only the *_label used to
# render it is localized.
class I18nRawDbValueLabelsTest < ActionDispatch::IntegrationTest
  setup { sign_out }

  # ---------------------------------------------------------------------
  # User::ROLES
  # ---------------------------------------------------------------------

  test "user role renders localized in both locales while the stored value stays English" do
    sign_in_as(users(:japanese_admin))

    get admin_users_url
    assert_select "span.badge", text: "管理者"
    assert_select "span.badge", text: "利用者"

    get edit_admin_user_url(users(:member))
    assert_select "select#user_role option[value=user]", text: "利用者"
    assert_select "select#user_role option[value=admin]", text: "管理者"

    sign_out
    sign_in_as(users(:admin))

    get admin_users_url
    assert_select "span.badge", text: "Admin"
    assert_select "span.badge", text: "User"

    assert_equal "user", users(:member).role
    assert_equal "admin", users(:admin).role
  end

  # ---------------------------------------------------------------------
  # AuditEvent::AUDITABLE_TYPES
  # ---------------------------------------------------------------------

  test "audit event record type renders as the localized model name while the stored value stays English" do
    event = AuditEvent.create!(
      auditable_type: "Patient", auditable_id: patients(:one).id,
      action: "update", record_label: patients(:one).to_s
    )

    sign_in_as(users(:japanese_admin))

    get audit_events_url
    assert_match "患者", response.body

    get audit_event_url(event)
    assert_select "dd", text: "患者"

    get audit_events_url(auditable_type: "Patient")
    assert_response :success

    assert_select "select#auditable_type option[value=Patient]", text: "患者"
    assert_select "select#auditable_type option[value=Surgery]", text: "手術"
    assert_select "select#auditable_type option[value=Hospitalization]", text: "入院"

    sign_out
    sign_in_as(users(:admin))

    get audit_event_url(event)
    assert_select "dd", text: "Patient"

    assert_equal "Patient", event.reload.auditable_type
  end

  # ---------------------------------------------------------------------
  # AuditEvent::ACTIONS
  # ---------------------------------------------------------------------

  test "audit event action renders localized on the index badge, show badge, and hospitalization history while the stored value stays English" do
    event = AuditEvent.create!(
      auditable_type: "Hospitalization", auditable_id: hospitalizations(:one).id,
      action: "update", record_label: hospitalizations(:one).to_s,
      change_data: { "reason" => [ "Old reason", hospitalizations(:one).reason ] }
    )

    sign_in_as(users(:japanese_admin))

    get audit_events_url
    assert_select "span.badge", text: "更新"

    get audit_event_url(event)
    assert_select "span.badge", text: "更新"

    get hospitalization_url(hospitalizations(:one))
    assert_select "span.badge", text: "更新"

    get audit_events_url(audit_action: "create")
    assert_select "select#audit_action option[value=create]", text: "作成"
    assert_select "select#audit_action option[value=update]", text: "更新"
    assert_select "select#audit_action option[value=destroy]", text: "削除"

    sign_out
    sign_in_as(users(:admin))

    get audit_event_url(event)
    assert_select "span.badge", text: "Update"

    assert_equal "update", event.reload.action
  end
end
