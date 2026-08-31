require "application_system_test_case"

class HospitalizationsTest < ApplicationSystemTestCase
  test "user can create hospitalization with multiple diagnoses" do
    visit new_hospitalization_path

    # Patient one (H001) already has an open-ended hospitalization fixture, so
    # this test uses patient two (H002) to avoid the overlap validation.
    select "H002 - Jane Smith", from: "Patient"
    page.execute_script(<<~JS)
      const admissionDateInput = document.querySelector("#hospitalization_admission_date")
      admissionDateInput.value = "2026-05-01"
      admissionDateInput.dispatchEvent(new Event("input", { bubbles: true }))
      admissionDateInput.dispatchEvent(new Event("change", { bubbles: true }))
    JS
    fill_in "Planned Length of Stay (Days)", with: "5"
    fill_in "Reason for Admission", with: "Fever and cough"
    select "Pneumonia", from: "Diagnosis"

    click_on "Add Diagnosis"
    assert_selector ".hospitalization-diagnosis-select", count: 2

    all(".hospitalization-diagnosis-select").last.select "Hypertension"

    assert_difference("Hospitalization.count", 1) do
      click_on "Create Hospitalization"
      assert_text "Hospitalization was successfully created."
    end

    assert_text "Pneumonia、Hypertension"
  end

  test "user can remove an added diagnosis row before saving" do
    visit new_hospitalization_path

    select "Pneumonia", from: "Diagnosis"

    click_on "Add Diagnosis"
    assert_selector "[data-hospitalization-diagnosis-fields-target='item']", count: 2

    all(".hospitalization-diagnosis-select").last.select "Hypertension"

    within(all("[data-hospitalization-diagnosis-fields-target='item']").last) do
      click_on "Remove"
    end

    assert_selector "[data-hospitalization-diagnosis-fields-target='item']", count: 1
  end
end
