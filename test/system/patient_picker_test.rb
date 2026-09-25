require "application_system_test_case"

class PatientPickerTest < ApplicationSystemTestCase
  test "user can search for a patient in the modal and select it" do
    visit new_surgery_path

    assert_text "No patient selected"

    click_on "Select Patient", match: :first
    within("turbo-frame#patient_picker_frame") do
      fill_in "Keyword", with: "H002"
      click_on "H002 - Jane Smith"
    end

    assert_no_selector "dialog#patient_picker_modal[open]"
    assert_text "H002"
    assert_text "Jane Smith"
    assert_no_text "No patient selected"
  end

  test "user can register a new patient from the picker modal and it gets selected" do
    visit new_surgery_path

    click_on "Select Patient", match: :first
    within("turbo-frame#patient_picker_frame") do
      click_on "Register New Patient"
      fill_in "Hospital ID", with: "H999"
      fill_in "Patient Name", with: "Newly Registered Patient"
      page.execute_script(<<~JS)
        const dateOfBirthInput = document.querySelector("#patient_date_of_birth")
        dateOfBirthInput.value = "1975-03-10"
        dateOfBirthInput.dispatchEvent(new Event("input", { bubbles: true }))
        dateOfBirthInput.dispatchEvent(new Event("change", { bubbles: true }))
      JS
      click_on "Create Patient"
    end

    # The create response replaces the whole frame element, so re-find it
    # here instead of asserting inside the `within` above, whose node goes
    # stale. The success frame closes the modal as soon as it connects,
    # hence visible: :all.
    assert_selector "turbo-frame#patient_picker_frame", text: "Patient was successfully created.", visible: :all

    assert_no_selector "dialog#patient_picker_modal[open]"
    assert_text "H999"
    assert_text "Newly Registered Patient"
  end
end
