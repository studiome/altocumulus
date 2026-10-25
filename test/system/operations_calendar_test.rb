require "application_system_test_case"

class OperationsCalendarSystemTest < ApplicationSystemTestCase
  DAY = Date.new(2026, 3, 4) # a Wednesday with two weekday slots and no surgeries

  test "switching tabs keeps the range and shows the examination ledger" do
    hospitalizations(:two).update_columns(purpose: "examination", scheduled_procedure_date: Date.new(2026, 3, 5),
                                          scheduled_admission_date: Date.new(2026, 3, 5), admission_date: nil, discharge_date: nil)
    visit operations_calendar_path(start: "2026-03-01", days: 7)

    assert_selector "[role=tab][aria-selected=true]", text: "Surgery"
    assert_selector ".oc-legend"
    click_on "Examination admission"

    assert_selector "[role=tab][aria-selected=true]", text: "Examination admission"
    assert_current_path(/view=examination/)
    assert_current_path(/start=2026-03-01/)
    assert_selector ".oc-day", count: 7
    within("tbody#day-2026-03-05") { assert_text "Jane Smith" }
    assert_no_selector ".oc-legend"
    assert_text "No examination admissions scheduled", minimum: 1
  end

  test "an admin edits a day's note in place and the day re-renders without a page load" do
    visit operations_calendar_path(start: "2026-03-01", days: 7)
    page.execute_script("window.__stays = true")

    find("tbody#day-#{DAY.iso8601}").hover
    within("tbody#day-#{DAY.iso8601}") { click_on "Add note" }
    within("turbo-frame#day-note-#{DAY.iso8601}") do
      fill_in "Note", with: "Staff meeting"
      fill_in "Slots", with: "1"
      click_on "Save"
    end

    within("tbody#day-#{DAY.iso8601}") do
      assert_text "Staff meeting"
      assert_text "Slots 1"
      assert_text "(changed)"
    end
    assert page.evaluate_script("window.__stays"), "the page was reloaded"
    assert_equal "Staff meeting", Holiday.find_by!(date: DAY).note

    find("tbody#day-#{DAY.iso8601}").hover
    within("tbody#day-#{DAY.iso8601}") { click_on "Edit" }
    within("turbo-frame#day-note-#{DAY.iso8601}") do
      fill_in "Note", with: ""
      click_on "Save"
      assert_text "must have"
    end
    within("turbo-frame#day-note-#{DAY.iso8601}") { accept_confirm { click_on "Delete this day's note" } }

    within("tbody#day-#{DAY.iso8601}") { assert_no_text "Staff meeting" }
    assert_nil Holiday.find_by(date: DAY)
  end

  test "an admin sets a day's special slot lanes in place and the day shows the changed marker" do
    SpecialSlotRule.create!(resource: surgery_locations(:cath_lab), day_of_week: DAY.wday, slot_count: 1)
    visit operations_calendar_path(start: "2026-03-01", days: 7)
    page.execute_script("window.__stays = true")

    find("tbody#day-#{DAY.iso8601}").hover
    within("tbody#day-#{DAY.iso8601}") { click_on "Edit special slots" }
    within("turbo-frame#day-special-slots-#{DAY.iso8601}") do
      fill_in "Cath Lab", with: "3"
      click_on "Save"
    end

    within("tbody#day-#{DAY.iso8601}") { assert_text "Cath Lab 0/3 lanes (0/540 min) (changed)" }
    assert page.evaluate_script("window.__stays"), "the page was reloaded"
    assert_equal 3, SpecialSlotDayOverride.find_by!(resource: surgery_locations(:cath_lab), date: DAY).slot_count
  end

  test "the edit link is reachable from the keyboard" do
    Holiday.create!(date: DAY, holiday: false, note: "Existing")
    visit operations_calendar_path(start: DAY.iso8601, days: 1)
    link = find("tbody#day-#{DAY.iso8601} a", exact_text: "Edit", visible: :all)
    page.execute_script("arguments[0].focus()", link)
    opacity = nil
    40.times do # the fade takes a moment
      opacity = page.evaluate_script("getComputedStyle(document.activeElement).opacity")
      break if opacity == "1"
      sleep 0.05
    end
    assert_equal "1", opacity
  end

  test "a non-admin sees the notes but no edit controls" do
    Holiday.create!(date: DAY, holiday: false, note: "Existing")
    users(:admin).user_roles.where(role: "admin").delete_all
    visit operations_calendar_path(start: "2026-03-03", days: 3)

    assert_text "Existing"
    assert_no_link "Edit", exact: true, visible: :all
    assert_no_link "Add note", visible: :all
  end
end
