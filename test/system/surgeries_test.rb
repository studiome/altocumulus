require "application_system_test_case"

class SurgeriesTest < ApplicationSystemTestCase
  test "the related-diagnosis picker offers only the selected patient's diagnoses" do
    visit new_surgery_path

    assert_text "Select a patient first."

    choose_patient "H001 - John Doe"
    await_surgery_diagnosis_fields
    click_on "Select Diagnosis", match: :first
    within("turbo-frame#surgery_diagnosis_picker_frame") do
      assert_text "Right Appendicitis"
      assert_text "Hypertension"
      assert_no_text "Bilateral Pneumonia"
      click_on "Close"
    end

    choose_patient "H002 - Jane Smith"
    await_surgery_diagnosis_fields
    click_on "Select Diagnosis", match: :first
    within("turbo-frame#surgery_diagnosis_picker_frame") do
      assert_text "Bilateral Pneumonia"
      assert_no_text "Right Appendicitis"
      assert_no_text "Hypertension"
    end
  end

  test "a picked related diagnosis is dropped when the patient changes" do
    visit new_surgery_path

    choose_patient "H001 - John Doe"
    await_surgery_diagnosis_fields
    choose_related_diagnosis "Right Appendicitis (2026-03-20)"
    assert_selector "[data-surgery-diagnosis-fields-target='item']", count: 1

    choose_patient "H002 - Jane Smith"

    assert_selector "[data-surgery-diagnosis-fields-target='item']", count: 0
    assert_text "No diagnoses selected yet."
  end

  test "the same related diagnosis cannot be picked twice" do
    visit new_surgery_path

    choose_patient "H001 - John Doe"
    await_surgery_diagnosis_fields
    choose_related_diagnosis "Right Appendicitis (2026-03-20)"
    choose_related_diagnosis "Right Appendicitis (2026-03-20)"

    assert_selector "[data-surgery-diagnosis-fields-target='item']", count: 1
  end

  test "user can create surgery from new surgery form" do
    visit new_surgery_path

    choose_patient "H001 - John Doe"
    await_surgery_diagnosis_fields
    choose_related_diagnosis "Right Appendicitis (2026-03-20)"
    page.execute_script(<<~JS)
      const surgeryDateInput = document.querySelector("#surgery_surgery_date")
      surgeryDateInput.value = "2026-04-17"
      surgeryDateInput.dispatchEvent(new Event("input", { bubbles: true }))
      surgeryDateInput.dispatchEvent(new Event("change", { bubbles: true }))
    JS
    choose_procedure "Cholecystectomy"
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

  test "user can search the procedure picker" do
    visit new_surgery_path

    choose_procedure "Cholecystectomy", keyword: "cystect"

    within(procedure_rows.first) { assert_text "Cholecystectomy" }
  end

  test "a procedure created from the picker modal is selected right away" do
    visit new_surgery_path

    click_on "Select Procedure", match: :first
    within("turbo-frame#surgery_procedure_picker_frame") do
      click_on "Register New Procedure"
      fill_in "Procedure Name", with: "Laparoscopic surgery"
      click_on "Create Surgery procedure"
    end

    # The create response replaces the whole frame element, so re-find it
    # here instead of asserting inside the `within` above, whose node goes
    # stale. The success frame closes the modal as soon as it connects,
    # hence visible: :all.
    assert_selector "turbo-frame#surgery_procedure_picker_frame", text: "Surgery procedure was successfully created.", visible: :all

    assert_no_selector "dialog#surgery_procedure_picker_modal[open]"
    within(procedure_rows.first) { assert_text "Laparoscopic surgery" }
  end

  test "a procedure created from the picker modal lands only on the row that opened it" do
    visit new_surgery_path

    click_on "Add Procedure"
    assert_selector "[data-surgery-procedure-fields-target='item']", count: 2

    within(procedure_rows.last) { click_on "Select Procedure" }
    within("turbo-frame#surgery_procedure_picker_frame") do
      click_on "Register New Procedure"
      fill_in "Procedure Name", with: "Laser ablation"
      click_on "Create Surgery procedure"
    end

    # The create response replaces the whole frame element, so re-find it
    # here instead of asserting inside the `within` above, whose node goes
    # stale. The success frame closes the modal as soon as it connects,
    # hence visible: :all.
    assert_selector "turbo-frame#surgery_procedure_picker_frame", text: "Surgery procedure was successfully created.", visible: :all

    assert_no_selector "dialog#surgery_procedure_picker_modal[open]"
    within(procedure_rows.last) { assert_text "Laser ablation" }
    within(procedure_rows.first) { assert_text "No procedure selected" }
  end

  test "removed procedures do not reappear after validation error" do
    visit new_surgery_path

    choose_patient "H001 - John Doe"
    await_surgery_diagnosis_fields
    choose_related_diagnosis "Right Appendicitis (2026-03-20)"
    page.execute_script(<<~JS)
      const surgeryDateInput = document.querySelector("#surgery_surgery_date")
      surgeryDateInput.value = "2026-04-17"
      surgeryDateInput.dispatchEvent(new Event("input", { bubbles: true }))
      surgeryDateInput.dispatchEvent(new Event("change", { bubbles: true }))
    JS

    # Pick the primary procedure
    choose_procedure "Cholecystectomy"

    # Add a second procedure
    click_on "Add Procedure"
    assert_selector "[data-surgery-procedure-fields-target='item']", count: 2

    choose_procedure "Appendectomy", scope: procedure_rows.last

    # Remove the second procedure
    within(procedure_rows.last) do
      click_on "Remove"
    end

    fill_in "Anesthesia Method", with: ""

    click_on "Create Surgery"

    # Should show validation error message
    assert_text "Anesthesia method can't be blank"

    # Verify that only 1 visible procedure row exists now
    assert_selector "[data-surgery-procedure-fields-target='item']", count: 1

    # Verify that the remaining visible row still shows "Cholecystectomy"
    within("[data-surgery-procedure-fields-target='item']") do
      assert_text "Cholecystectomy"
    end
  end

  test "the slot category picker shows only the fields that category needs" do
    visit new_surgery_path

    # Regular slot is the default: the slot number is asked for, the
    # partner-department and location fields stay out of the way.
    assert_selector "#surgery_slot_number", visible: true
    assert_no_selector "#surgery_target_department", visible: true
    assert_no_selector "#surgery_location", visible: true

    choose "Joint/Simultaneous Surgery"
    assert_selector "#surgery_target_department", visible: true
    assert_no_selector "#surgery_slot_number", visible: true
    assert_no_selector "#surgery_location", visible: true

    choose "Backup/Standby"
    assert_selector "#surgery_target_department", visible: true
    assert_no_selector "#surgery_location", visible: true

    choose "Procedure Room / Off-slot"
    assert_selector "#surgery_location", visible: true
    assert_no_selector "#surgery_target_department", visible: true
    assert_no_selector "#surgery_slot_number", visible: true

    choose "Regular Slot"
    assert_selector "#surgery_slot_number", visible: true
    assert_no_selector "#surgery_target_department", visible: true
    assert_no_selector "#surgery_location", visible: true
  end

  test "an emergency surgery is not asked for a slot number" do
    visit new_surgery_path

    assert_selector "#surgery_slot_number", visible: true

    choose "Emergency"
    assert_no_selector "#surgery_slot_number", visible: true

    choose "Elective"
    assert_selector "#surgery_slot_number", visible: true
  end

  test "the slot category options stay inside their own boxes" do
    # The form is rendered in a max-w-xl card, so a picker laid out in four
    # fixed columns cannot hold a label like "Joint/Simultaneous Surgery":
    # the text spills over the neighbouring option and out of the card. Both
    # widths are pinned here because the layout switches column count at sm.
    [ [ 1400, 1400 ], [ 500, 900 ] ].each do |width, height|
      page.driver.browser.manage.window.resize_to(width, height)
      visit edit_surgery_path(surgeries(:three))
      assert_text "Slot Category"

      overflowing = page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll('input[name="surgery[slot_category]"]')).filter(radio => {
          const box = radio.closest("label");
          return box.scrollWidth > Math.ceil(box.getBoundingClientRect().width) + 1;
        }).map(radio => radio.value)
      JS

      assert_empty overflowing, "slot category options overflow their boxes at #{width}px: #{overflowing.inspect}"
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  private

    def procedure_rows
      all("[data-surgery-procedure-fields-target='item']")
    end
end
