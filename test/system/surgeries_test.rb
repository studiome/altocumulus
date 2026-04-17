require "application_system_test_case"

class SurgeriesTest < ApplicationSystemTestCase
  test "diagnosis options are filtered by selected patient" do
    visit new_surgery_path

    assert_text "Right Appendicitis"
    assert_text "Hypertension"
    assert_text "Bilateral Pneumonia"

    select "H001 - John Doe", from: "Patient"

    assert_text "Right Appendicitis"
    assert_text "Hypertension"
    assert_no_text "Bilateral Pneumonia"

    select "H002 - Jane Smith", from: "Patient"

    assert_text "Bilateral Pneumonia"
    assert_no_text "Right Appendicitis"
    assert_no_text "Hypertension"
  end

  test "user can create surgery from new surgery form" do
    visit new_surgery_path

    select "H001 - John Doe", from: "Patient"
    check "Right Appendicitis"
    page.execute_script(<<~JS)
      const surgeryDateInput = document.querySelector("#surgery_surgery_date")
      surgeryDateInput.value = "2026-04-17"
      surgeryDateInput.dispatchEvent(new Event("input", { bubbles: true }))
      surgeryDateInput.dispatchEvent(new Event("change", { bubbles: true }))
    JS
    select "Cholecystectomy", from: "Procedure"
    select "Bilateral", from: "Laterality"
    fill_in "Duration (hours)", with: "2.5"
    fill_in "Anesthesia Method", with: "General anesthesia"

    assert_difference("Surgery.count", 1) do
      click_on "Create Surgery"
      assert_text "Surgery was successfully created."
    end

    assert_text "Bilateral Cholecystectomy"
    assert_text "Right Appendicitis"
  end
end
