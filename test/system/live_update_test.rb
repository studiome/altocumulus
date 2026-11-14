require "application_system_test_case"

# Another user's change reaches an open screen without a reload. The model is
# changed in the test body (another "user"); the test cable adapter delivers
# the signal to the browser in-process.
class LiveUpdateSystemTest < ApplicationSystemTestCase
  DAY = Date.new(2026, 3, 4) # a Wednesday with no surgeries

  def wait_for_live_connection
    assert_selector "turbo-cable-stream-source[connected]", visible: :all, wait: 10
  end

  test "a calendar day picks up a surgery changed elsewhere" do
    visit operations_calendar_path(start: "2026-03-01", days: 7)
    wait_for_live_connection
    page.execute_script("window.__stays = true")
    within("tbody#day-#{DAY.iso8601}") { assert_no_text "Jane Smith" }

    surgeries(:two).update!(surgery_date: DAY)

    within("tbody#day-#{DAY.iso8601}") { assert_text "Jane Smith" }
    assert page.evaluate_script("window.__stays"), "the page must not have reloaded"
  end

  test "a day with an open note editor is not replaced until the editor closes" do
    visit operations_calendar_path(start: "2026-03-01", days: 7)
    wait_for_live_connection
    find("tbody#day-#{DAY.iso8601}").hover
    within("tbody#day-#{DAY.iso8601}") { click_on "Add note" }
    within("turbo-frame#day-note-#{DAY.iso8601}") { fill_in "Note", with: "Typing in progress" }

    surgeries(:two).update!(surgery_date: DAY)

    # The editor and its text survive while the signal is pending.
    sleep 1.5 # the debounce plus one retry would have replaced the day by now
    within("tbody#day-#{DAY.iso8601}") do
      assert_field "Note", with: "Typing in progress"
      assert_no_text "Jane Smith"
    end

    within("turbo-frame#day-note-#{DAY.iso8601}") { click_on "Cancel" }
    within("tbody#day-#{DAY.iso8601}") { assert_text "Jane Smith", wait: 10 }
  end
end
