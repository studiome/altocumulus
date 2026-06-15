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

  test "user can dynamically add a new surgery procedure and select it" do
    visit new_surgery_path

    # Open procedure modal
    click_on "New Procedure", match: :first

    within("turbo-frame#surgery_procedure_modal_frame") do
      fill_in "Procedure Name", with: "Laparoscopic surgery"
      click_on "Create Surgery procedure"
    end

    # Wait for the modal dialog to close/disappear and check option selection
    assert_equal "Laparoscopic surgery", find(".surgery-procedure-select").find("option:checked").text

    # Click "Add Procedure" to add a new row
    click_on "Add Procedure"

    # Verify that the new row (from the template) also contains the new option
    selects = all(".surgery-procedure-select")
    assert_equal 2, selects.size
    selects.each do |select|
      assert select.has_selector?("option", text: "Laparoscopic surgery")
    end
  end

  test "removed procedures do not reappear after validation error" do
    visit new_surgery_path

    select "H001 - John Doe", from: "Patient"
    check "Right Appendicitis"
    page.execute_script(<<~JS)
      const surgeryDateInput = document.querySelector("#surgery_surgery_date")
      surgeryDateInput.value = "2026-04-17"
      surgeryDateInput.dispatchEvent(new Event("input", { bubbles: true }))
      surgeryDateInput.dispatchEvent(new Event("change", { bubbles: true }))
    JS

    # Select primary procedure
    select "Cholecystectomy", from: "Procedure"

    # Add a second procedure
    click_on "Add Procedure"
    
    # Wait until 2 select inputs are present
    assert_selector ".surgery-procedure-select", count: 2
    
    # Select procedure in the newly added dropdown
    second_select = all(".surgery-procedure-select").last
    second_select.select "Appendectomy"

    # Remove the second procedure
    within(all("[data-surgery-procedure-fields-target='item']").last) do
      click_on "Remove"
    end

    # Confirm it is hidden dynamically on the client-side
    assert_no_selector "option:checked", text: "Appendectomy"

    # Keep "Anesthesia Method" blank (which is required) to trigger a validation error
    fill_in "Anesthesia Method", with: ""

    click_on "Create Surgery"

    # Should show validation error message
    assert_text "Anesthesia method can't be blank"

    # Verify that only 1 visible procedure row exists now
    assert_selector "[data-surgery-procedure-fields-target='item']", count: 1

    # Verify that the remaining visible row contains "Cholecystectomy"
    within("[data-surgery-procedure-fields-target='item']") do
      assert_equal "Cholecystectomy", find(".surgery-procedure-select").find("option:checked").text
    end
  end
end
