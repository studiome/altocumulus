require "application_system_test_case"

class PatientDiagnosesTest < ApplicationSystemTestCase
  setup do
    @patient = patients(:one)
  end

  test "user can add a diagnosis from the patient list and save the entry" do
    visit patients_path

    within("tr", text: @patient.hospital_id) do
      click_on "Add Diagnosis"
    end

    assert_text "New Diagnosis Entry"

    click_on "New Diagnosis", match: :first

    within("turbo-frame#diagnosis_modal_frame") do
      fill_in "Diagnosis Name", with: "Migraine with aura"
      click_on "Create Diagnosis"
    end

    assert_selector "option[selected]", text: "Migraine with aura"

    page.execute_script(<<~JS)
      const diagnosedOnInput = document.querySelector("#patient_diagnosis_diagnosed_on")
      diagnosedOnInput.value = "2026-04-17"
      diagnosedOnInput.dispatchEvent(new Event("input", { bubbles: true }))
      diagnosedOnInput.dispatchEvent(new Event("change", { bubbles: true }))
    JS

    assert_difference("PatientDiagnosis.count", 1) do
      click_on "Save Diagnosis Entry"
      assert_text "Diagnosis entry was successfully created."
    end

    assert_text @patient.name
    assert_text "Migraine with aura"
    assert_text "2026-04-17"
  end
end
