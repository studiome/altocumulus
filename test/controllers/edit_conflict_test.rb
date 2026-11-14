require "test_helper"

# The four edit forms refuse a stale save and offer "Load the latest" /
# "Save anyway" (see EditConflictGuard).
class EditConflictTest < ActionDispatch::IntegrationTest
  def changed_by_member(record, **attributes)
    Current.set(user: users(:member)) { record.update!(attributes) }
  end

  def assert_conflict_page(record, edit_path:, typed:, models: [ record ])
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Member User/
    assert_select "button[name=overwrite][value='1']"
    assert_select "a[href=?]", edit_path
    assert_select "input[name=edit_version][value=?]", EditVersion.for(*models).to_s
    assert_includes response.body, typed
  end

  # ---- patients ----

  test "patients: a stale save is refused, shows the editor and keeps the input" do
    patient = patients(:one)
    token = EditVersion.for(patient)
    changed_by_member(patient, name: "Someone Else")

    patch patient_url(patient), params: { patient: { name: "My Typing" }, edit_version: token }

    assert_conflict_page(patient, edit_path: edit_patient_path(patient), typed: "My Typing")
    assert_equal "Someone Else", patient.reload.name
  end

  test "patients: overwrite, a matching token and no token all save" do
    patient = patients(:one)

    patch patient_url(patient), params: { patient: { name: "Matching" }, edit_version: EditVersion.for(patient) }
    assert_redirected_to patient_url(patient)
    assert_equal "Matching", patient.reload.name

    stale = EditVersion.for(patient)
    changed_by_member(patient, name: "Other")
    patch patient_url(patient), params: { patient: { name: "Forced" }, edit_version: stale, overwrite: "1" }
    assert_equal "Forced", patient.reload.name

    patch patient_url(patient), params: { patient: { name: "No Token" } }
    assert_equal "No Token", patient.reload.name
  end

  test "patients: the edit form carries the current token and a validation failure keeps the submitted one" do
    patient = patients(:one)
    get edit_patient_url(patient)
    assert_select "input[name=edit_version][value=?]", EditVersion.for(patient).to_s

    token = EditVersion.for(patient)
    patch patient_url(patient), params: { patient: { name: "" }, edit_version: token }
    assert_response :unprocessable_entity
    assert_select "input[name=edit_version][value=?]", token.to_s
    assert_select "button[name=overwrite]", count: 0
  end

  test "patients: another change after a failed submit still warns" do
    patient = patients(:one)
    token = EditVersion.for(patient)
    patch patient_url(patient), params: { patient: { name: "" }, edit_version: token }
    changed_by_member(patient, name: "Meanwhile")

    patch patient_url(patient), params: { patient: { name: "Fixed" }, edit_version: token }

    assert_response :unprocessable_entity
    assert_equal "Meanwhile", patient.reload.name
  end

  test "a conflict page asks again when yet another change comes in" do
    patient = patients(:one)
    token = EditVersion.for(patient)
    changed_by_member(patient, name: "First")
    patch patient_url(patient), params: { patient: { name: "Mine" }, edit_version: token }
    fresh = css_select("input[name=edit_version]").first["value"]
    changed_by_member(patient, name: "Second")

    patch patient_url(patient), params: { patient: { name: "Mine" }, edit_version: fresh }

    assert_response :unprocessable_entity
    assert_equal "Second", patient.reload.name
  end

  # ---- hospitalizations ----

  test "hospitalizations: a stale save is refused, overwrite and matching token save" do
    hospitalization = hospitalizations(:one)
    token = EditVersion.for(hospitalization)
    changed_by_member(hospitalization, reason: "Other reason")

    patch hospitalization_url(hospitalization), params: { hospitalization: { reason: "My reason" }, edit_version: token }

    assert_conflict_page(hospitalization, edit_path: edit_hospitalization_path(hospitalization), typed: "My reason")
    assert_equal "Other reason", hospitalization.reload.reason

    patch hospitalization_url(hospitalization), params: { hospitalization: { reason: "Forced" }, edit_version: token, overwrite: "1" }
    assert_redirected_to hospitalization_url(hospitalization)
    assert_equal "Forced", hospitalization.reload.reason

    patch hospitalization_url(hospitalization), params: { hospitalization: { reason: "Matching" }, edit_version: EditVersion.for(hospitalization) }
    assert_equal "Matching", hospitalization.reload.reason

    patch hospitalization_url(hospitalization), params: { hospitalization: { reason: "No token" } }
    assert_equal "No token", hospitalization.reload.reason
  end

  test "hospitalizations: the edit form carries the token" do
    hospitalization = hospitalizations(:one)
    get edit_hospitalization_url(hospitalization)

    assert_select "input[name=edit_version][value=?]", EditVersion.for(hospitalization).to_s
  end

  # ---- surgeries ----

  test "surgeries: a stale save is refused, overwrite and matching token save" do
    surgery = surgeries(:one)
    token = EditVersion.for(surgery)
    changed_by_member(surgery, operator_name: "Dr. Other")

    patch surgery_url(surgery), params: { surgery: { operator_name: "Dr. Mine" }, edit_version: token }

    assert_conflict_page(surgery, edit_path: edit_surgery_path(surgery), typed: "Dr. Mine")
    assert_equal "Dr. Other", surgery.reload.operator_name

    patch surgery_url(surgery), params: { surgery: { operator_name: "Dr. Forced" }, edit_version: token, overwrite: "1" }
    assert_equal "Dr. Forced", surgery.reload.operator_name

    patch surgery_url(surgery), params: { surgery: { operator_name: "Dr. Matching" }, edit_version: EditVersion.for(surgery) }
    assert_equal "Dr. Matching", surgery.reload.operator_name

    patch surgery_url(surgery), params: { surgery: { operator_name: "Dr. None" } }
    assert_equal "Dr. None", surgery.reload.operator_name
  end

  test "surgeries: the edit form carries the token" do
    surgery = surgeries(:one)
    get edit_surgery_url(surgery)

    assert_select "input[name=edit_version][value=?]", EditVersion.for(surgery).to_s
  end

  # ---- reservations ----

  test "reservations: the version covers the hospitalization and its surgery" do
    hospitalization = hospitalizations(:one)
    surgery = surgeries(:one)
    surgery.update!(hospitalization: hospitalization)
    token = EditVersion.for(hospitalization, surgery)
    changed_by_member(surgery, operator_name: "Dr. Other")

    patch reservation_url(hospitalization), params: { reservation: { hospitalization: { reason: "My reason" } }, edit_version: token }

    assert_conflict_page(hospitalization, edit_path: edit_reservation_path(hospitalization), typed: "My reason", models: [ hospitalization, surgery ])
    assert_not_equal "My reason", hospitalization.reload.reason

    patch reservation_url(hospitalization), params: { reservation: { hospitalization: { reason: "Forced" } }, edit_version: token, overwrite: "1" }
    assert_equal "Forced", hospitalization.reload.reason

    patch reservation_url(hospitalization), params: { reservation: { hospitalization: { reason: "Matching" } }, edit_version: EditVersion.for(hospitalization, surgery) }
    assert_equal "Matching", hospitalization.reload.reason

    patch reservation_url(hospitalization), params: { reservation: { hospitalization: { reason: "No token" } } }
    assert_equal "No token", hospitalization.reload.reason
  end

  test "reservations: the edit form carries the token and watches both records" do
    hospitalization = hospitalizations(:one)
    surgery = surgeries(:one)
    surgery.update!(hospitalization: hospitalization)
    get edit_reservation_url(hospitalization)

    assert_select "input[name=edit_version][value=?]", EditVersion.for(hospitalization, surgery).to_s
    assert_select "[data-controller~=live-edit-notice][data-live-edit-notice-records-value=?]", "Hospitalization:#{hospitalization.id} Surgery:#{surgery.id}"
  end

  test "the new forms carry no token" do
    get new_patient_url
    assert_select "input[name=edit_version]", count: 0
  end
end
