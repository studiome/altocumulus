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

  test "a reservation form's slot summary, admission count and side calendar follow other users' changes" do
    visit new_reservation_path(purpose: "surgery")
    wait_for_live_connection
    set_date "reservation_surgery_surgery_date", Date.new(2026, 3, 3)
    assert_selector "turbo-frame#reservation_slot_summary", text: "2 / 3 slots"
    set_date "reservation_hospitalization_scheduled_admission_date", Date.new(2026, 3, 1)
    assert_selector "turbo-frame#reservation_admission_count", text: /Admissions already scheduled that day: \d+/
    before = find("turbo-frame#reservation_admission_count").text[/that day: (\d+)/, 1].to_i
    assert_selector "turbo-frame#reservation_admission_calendar h3", text: "3/2026"

    surgeries(:six).update!(slot_number: 3)
    assert_selector "turbo-frame#reservation_slot_summary", text: "3 / 3 slots"

    hospitalizations(:four).update!(scheduled_admission_date: Date.new(2026, 3, 1), planned_days: 2)
    assert_selector "turbo-frame#reservation_admission_count", text: "that day: #{before + 1}"
    assert_selector "turbo-frame#reservation_admission_calendar h3", text: "3/2026"
    assert_field "Surgery Date", with: "2026-03-03"
  end

  test "a patient show page updates when the patient is renamed elsewhere" do
    visit patient_path(patients(:one))
    wait_for_live_connection
    assert_text "John Doe"

    patients(:one).update!(name: "Renamed Elsewhere")

    assert_text "Renamed Elsewhere"
  end

  test "a hospitalization show page updates when the hospitalization changes elsewhere" do
    hospitalization = hospitalizations(:one)
    visit hospitalization_path(hospitalization)
    wait_for_live_connection
    assert_text "Community-acquired pneumonia"

    hospitalization.update!(reason: "Changed by someone else")

    assert_text "Changed by someone else"
  end

  test "a surgery show page updates when the surgery changes elsewhere" do
    surgery = surgeries(:one)
    visit surgery_path(surgery)
    wait_for_live_connection

    surgery.update!(operator_name: "Dr. Elsewhere")

    assert_text "Dr. Elsewhere"
  end

  test "the patients list shows a patient created elsewhere" do
    visit patients_path
    wait_for_live_connection
    assert_no_text "Brand New Patient"

    Patient.create!(hospital_id: "H900", name: "Brand New Patient", date_of_birth: Date.new(2000, 1, 1))

    assert_text "Brand New Patient"
  end

  test "typed but unsubmitted filter text survives a refresh" do
    visit patients_path
    wait_for_live_connection
    find("input[name=keyword]").fill_in(with: "half typed")
    find("h1").click # leave the field: a focused field would only defer the refresh

    Patient.create!(hospital_id: "H901", name: "Arrived While Typing", date_of_birth: Date.new(2000, 1, 1))

    # The filter is not applied, so the new patient is listed, and the text stays.
    assert_text "Arrived While Typing"
    assert_equal "half typed", find("input[name=keyword]").value
  end

  test "a list refresh keeps the applied filter and the current page" do
    26.times { |n| Patient.create!(hospital_id: format("HB%03d", n), name: "Bulk #{format('%02d', n)}", date_of_birth: Date.new(2000, 1, 1)) }
    visit patients_path(keyword: "Bulk", page: 2)
    wait_for_live_connection
    assert_selector "tbody tr", count: 1
    row_name = find("tbody tr td.font-semibold").text

    Patient.find_by!(name: row_name).update!(name: "#{row_name} renamed")
    # Not matching the filter: must not show up.
    Patient.create!(hospital_id: "H902", name: "Other Name", date_of_birth: Date.new(2000, 1, 1))

    assert_text "#{row_name} renamed"
    assert_no_text "Other Name"
    assert_current_path(/keyword=Bulk&page=2/)
    assert_equal "Bulk", find("input[name=keyword]").value
  end

  test "a surgery list row updates elsewhere while the filter stays" do
    visit surgeries_path(keyword: "Doe")
    wait_for_live_connection
    assert_text "John Doe"
    assert_no_text "Jane Smith"

    surgeries(:one).update!(operator_name: "Dr. Row Update")

    assert_text "Dr. Row Update"
    assert_no_text "Jane Smith"
    assert_current_path(/keyword=Doe/)
  end

  test "a hospitalization list row updates elsewhere" do
    hospitalization = hospitalizations(:one)
    visit hospitalizations_path(admitted_from: "2026-01-01")
    wait_for_live_connection
    assert_text "Community-acquired pneumonia"

    hospitalization.update!(reason: "Row changed elsewhere")

    assert_text "Row changed elsewhere"
  end

  def set_date(field_id, date)
    page.execute_script(<<~JS)
      const input = document.querySelector("##{field_id}")
      input.value = "#{date.iso8601}"
      input.dispatchEvent(new Event("input", { bubbles: true }))
      input.dispatchEvent(new Event("change", { bubbles: true }))
    JS
  end
end
