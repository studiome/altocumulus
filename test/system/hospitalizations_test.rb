require "application_system_test_case"

class HospitalizationsTest < ApplicationSystemTestCase
  test "user can create hospitalization with multiple diagnoses" do
    visit new_hospitalization_path

    # Patient one (H001) already has an open-ended hospitalization fixture, so
    # this test uses patient two (H002) to avoid the overlap validation.
    choose_patient "H002 - Jane Smith"
    page.execute_script(<<~JS)
      const admissionDateInput = document.querySelector("#hospitalization_admission_date")
      admissionDateInput.value = "2026-05-01"
      admissionDateInput.dispatchEvent(new Event("input", { bubbles: true }))
      admissionDateInput.dispatchEvent(new Event("change", { bubbles: true }))
    JS
    fill_in "Planned Length of Stay (Days)", with: "5"
    fill_in "Reason for Admission", with: "Fever and cough"
    choose_diagnosis "Pneumonia"

    click_on "Add Diagnosis"
    assert_selector "[data-hospitalization-diagnosis-fields-target='item']", count: 2

    choose_diagnosis "Hypertension", scope: diagnosis_rows.last

    assert_difference("Hospitalization.count", 1) do
      click_on "Create Hospitalization"
      assert_text "Hospitalization was successfully created."
    end

    assert_text "Pneumonia, Hypertension"
  end

  test "the diagnosis picked in the modal is shown on the row that opened it" do
    visit new_hospitalization_path

    click_on "Add Diagnosis"
    assert_selector "[data-hospitalization-diagnosis-fields-target='item']", count: 2

    choose_diagnosis "Hypertension", scope: diagnosis_rows.last

    within(diagnosis_rows.first) { assert_text "No diagnosis selected" }
    within(diagnosis_rows.last) { assert_text "Hypertension" }
  end

  test "user can search the diagnosis picker" do
    visit new_hospitalization_path

    choose_diagnosis "Hypertension", keyword: "ypert"

    within(diagnosis_rows.first) { assert_text "Hypertension" }
  end

  test "a diagnosis created from the picker modal is selected right away" do
    visit new_hospitalization_path

    click_on "Select Diagnosis", match: :first
    within("turbo-frame#diagnosis_picker_frame") do
      click_on "Register New Diagnosis"
      fill_in "Diagnosis Name", with: "Acute gastritis"
      click_on "Create Diagnosis"
    end

    # The create response replaces the whole frame element, so re-find it
    # here instead of asserting inside the `within` above, whose node goes
    # stale. The success frame closes the modal as soon as it connects,
    # hence visible: :all.
    assert_selector "turbo-frame#diagnosis_picker_frame", text: "Diagnosis was successfully created.", visible: :all

    assert_no_selector "dialog#diagnosis_picker_modal[open]"
    within(diagnosis_rows.first) { assert_text "Acute gastritis" }
  end

  test "user can remove an added diagnosis row before saving" do
    visit new_hospitalization_path

    choose_diagnosis "Pneumonia"

    click_on "Add Diagnosis"
    assert_selector "[data-hospitalization-diagnosis-fields-target='item']", count: 2

    choose_diagnosis "Hypertension", scope: diagnosis_rows.last

    within(diagnosis_rows.last) do
      click_on "Remove"
    end

    assert_selector "[data-hospitalization-diagnosis-fields-target='item']", count: 1
  end

  private

    def diagnosis_rows
      all("[data-hospitalization-diagnosis-fields-target='item']")
    end
end
