require "application_system_test_case"

class ReservationsTest < ApplicationSystemTestCase
  # Patient two (H002) has no open-ended hospitalization, so a future booking
  # never trips the overlap validation.
  setup do
    @admission = Date.current + 9
    @surgery_date = Date.current + 10
  end

  def set_date(field_id, date)
    page.execute_script(<<~JS)
      const input = document.querySelector("##{field_id}")
      input.value = "#{date.iso8601}"
      input.dispatchEvent(new Event("input", { bubbles: true }))
      input.dispatchEvent(new Event("change", { bubbles: true }))
    JS
  end

  test "booking from the calendar's day link takes one screen and lands back on the calendar" do
    visit operations_calendar_path(start: @surgery_date.iso8601, days: 1)
    click_on I18n.l(@surgery_date, format: :default, locale: :en), match: :first

    assert_current_path(/\/reservations\/new/)
    assert_field "Surgery Date", with: @surgery_date.iso8601

    choose_patient "H002 - Jane Smith"
    within("[data-testid=patient-card]") do
      assert_text "H002"
      assert_text "Jane Smith"
      assert_text "Check that the ID and name match the paper chart"
    end

    set_date "reservation_hospitalization_scheduled_admission_date", @admission
    assert_selector "turbo-frame#reservation_admission_count", text: "Admissions already scheduled that day"
    fill_in "Planned Length of Stay (Days)", with: "5"

    choose_diagnosis "Pneumonia"
    choose_procedure "Cholecystectomy"
    fill_in "Duration (hours)", with: "2"
    fill_in "Anesthesia Method", with: "General anesthesia"

    assert_difference [ "Hospitalization.count", "Surgery.count" ], 1 do
      click_on "Register Reservation"
      assert_text "Reservation was successfully registered."
    end

    assert_current_path(/operations_calendar/)
    within("tbody#day-#{@surgery_date.iso8601}") do
      assert_text "Jane Smith"
      assert_text "Cholecystectomy"
    end
    assert_selector "tbody#day-#{@surgery_date.iso8601}.oc-day-highlight"
  end

  test "the admission date follows the surgery date until it is edited by hand" do
    visit new_reservation_path(purpose: "surgery")
    admission = "reservation_hospitalization_scheduled_admission_date"

    set_date "reservation_surgery_surgery_date", @surgery_date
    assert_field "Scheduled Admission Date", with: (@surgery_date - 1).iso8601
    assert_selector "turbo-frame#reservation_admission_count", text: "Admissions already scheduled that day"

    set_date "reservation_surgery_surgery_date", @surgery_date + 3
    assert_field "Scheduled Admission Date", with: (@surgery_date + 2).iso8601

    set_date admission, @admission
    set_date "reservation_surgery_surgery_date", @surgery_date + 5
    assert_field "Scheduled Admission Date", with: @admission.iso8601
    assert_equal @admission.iso8601, find("##{admission}").value
  end

  test "an admission date from the link is not overwritten by a surgery date change" do
    visit new_reservation_path(purpose: "surgery", scheduled_admission_date: @admission.iso8601)
    set_date "reservation_surgery_surgery_date", @surgery_date
    assert_field "Scheduled Admission Date", with: @admission.iso8601
  end

  test "choosing a non-surgery purpose hides the surgery section and shows the procedure fields" do
    visit new_reservation_path(purpose: "surgery")

    assert_selector "#reservation-surgery-heading"
    assert_no_field "Procedure name"

    select "Examination / Procedure", from: "Purpose"
    assert_no_selector "#reservation-surgery-heading"
    assert_field "Procedure name"
    assert_field "Scheduled procedure date"

    select "Surgery", from: "Purpose"
    assert_selector "#reservation-surgery-heading"
    assert_no_field "Procedure name"
  end

  test "an examination reservation is saved without any surgery fields" do
    visit new_reservation_path(purpose: "examination")

    choose_patient "H002 - Jane Smith"
    set_date "reservation_hospitalization_scheduled_admission_date", @admission
    choose_diagnosis "Pneumonia"
    fill_in "Procedure name", with: "Colonoscopy"

    assert_difference "Hospitalization.count", 1 do
      assert_no_difference "Surgery.count" do
        click_on "Register Reservation"
        assert_text "Reservation was successfully registered."
      end
    end
    assert_text "Colonoscopy"
  end

  test "the protocol field follows the purpose, is not submitted when hidden, and the choice shows on the calendar" do
    visit new_reservation_path(purpose: "examination")
    assert_no_button "Select Protocol"
    assert_no_link "Select Protocol"

    select "Chemotherapy", from: "Purpose"
    assert_link "Select Protocol"
    assert_selector "label", text: "Chemotherapy protocol"
    choose_protocol "Protocol B"
    assert_selector "[data-picker-field-target=display]", text: "Protocol B"

    select "Examination / Procedure", from: "Purpose"
    assert_no_link "Select Protocol"
    assert find("#reservation_hospitalization_chemotherapy_protocol_id", visible: :all).disabled?

    select "Chemoradiotherapy", from: "Purpose"
    assert_selector "[data-picker-field-target=display]", text: "Protocol B"
    assert_not find("#reservation_hospitalization_chemotherapy_protocol_id", visible: :all).disabled?

    choose_patient "H002 - Jane Smith"
    set_date "reservation_hospitalization_scheduled_admission_date", @admission
    choose_diagnosis "Pneumonia"

    assert_difference "Hospitalization.count", 1 do
      click_on "Register Reservation"
      assert_text "Reservation was successfully registered."
    end
    assert_equal "Protocol B", Hospitalization.order(:id).last.chemotherapy_protocol.name

    visit operations_calendar_path(view: "admission", start: @admission.iso8601, days: 1)
    within("tbody#day-#{@admission.iso8601}") do
      assert_text "Jane Smith"
      assert_text "Protocol B"
    end
    visit operations_calendar_path(view: "chemotherapy", start: @admission.iso8601, days: 1)
    within("tbody#day-#{@admission.iso8601}") do
      assert_text "Jane Smith"
      assert_text "Protocol B"
    end
  end

  test "the protocol picker offers only active protocols and filters by keyword" do
    visit new_reservation_path(purpose: "chemotherapy")
    open_protocol_picker
    within("turbo-frame#chemotherapy_protocol_picker_frame") do
      assert_button "Protocol A"
      assert_button "Protocol B"
      assert_no_button "Retired Protocol"
      fill_in "Keyword", with: "Protocol B"
      click_on "Search"
      assert_button "Protocol B"
      assert_no_button "Protocol A"
    end
  end

  test "a non-admin registers a new protocol from inside the modal and it lands in the field and is saved" do
    # The suite signs in as the admin; take that role away so every request of
    # this session is a plain user's.
    users(:admin).update!(roles: [ "user" ])
    visit new_reservation_path(purpose: "chemotherapy")

    open_protocol_picker
    within("turbo-frame#chemotherapy_protocol_picker_frame") do
      click_on "Register New Protocol"
      fill_in "Name", with: "Brand New Regimen"
      assert_difference "ChemotherapyProtocol.count", 1 do
        click_on "Register Protocol"
        assert_no_selector "input[name='chemotherapy_protocol[name]']", wait: 5
      end
    end
    assert_no_selector "dialog#chemotherapy_protocol_picker_modal[open]"
    assert_selector "[data-picker-field-target=display]", text: "Brand New Regimen"
    created = ChemotherapyProtocol.find_by!(name: "Brand New Regimen")
    assert created.active?
    assert_equal created.id.to_s, find("#reservation_hospitalization_chemotherapy_protocol_id", visible: :all).value

    choose_patient "H002 - Jane Smith"
    set_date "reservation_hospitalization_scheduled_admission_date", @admission
    choose_diagnosis "Pneumonia"
    click_on "Register Reservation"
    assert_text "Reservation was successfully registered."
    assert_equal created, Hospitalization.order(:id).last.chemotherapy_protocol
  end

  test "a duplicate protocol name shows its error inside the modal" do
    visit new_reservation_path(purpose: "chemotherapy")
    open_protocol_picker
    within("turbo-frame#chemotherapy_protocol_picker_frame") do
      click_on "Register New Protocol"
      fill_in "Name", with: "Protocol A"
      click_on "Register Protocol"
      assert_selector ".alert-error", text: /taken/i
    end
    assert_selector "dialog#chemotherapy_protocol_picker_modal[open]"
  end

  test "clearing the protocol field saves it empty, and an inactive protocol stays until cleared" do
    hospitalization = hospitalizations(:one)
    hospitalization.update_columns(purpose: "chemotherapy", chemotherapy_protocol_id: chemotherapy_protocols(:retired_protocol).id)

    visit edit_reservation_path(hospitalization)
    assert_selector "[data-picker-field-target=display]", text: "Retired Protocol"
    click_on "Save Reservation"
    assert_text "Reservation was successfully updated."
    assert_equal chemotherapy_protocols(:retired_protocol).id, hospitalization.reload.chemotherapy_protocol_id

    visit edit_reservation_path(hospitalization)
    click_on "Clear"
    assert_selector "[data-picker-field-target=display]", text: "No protocol selected"
    assert_equal "", find("#reservation_hospitalization_chemotherapy_protocol_id", visible: :all).value
    click_on "Save Reservation"
    assert_text "Reservation was successfully updated."
    assert_nil hospitalization.reload.chemotherapy_protocol_id
  end

  test "switching away from a protocol purpose submits no protocol" do
    visit new_reservation_path(purpose: "chemotherapy")
    choose_protocol "Protocol A"
    select "Examination / Procedure", from: "Purpose"

    choose_patient "H002 - Jane Smith"
    set_date "reservation_hospitalization_scheduled_admission_date", @admission
    choose_diagnosis "Pneumonia"
    click_on "Register Reservation"
    assert_text "Reservation was successfully registered."
    assert_nil Hospitalization.order(:id).last.chemotherapy_protocol_id
  end

  test "booking from the chemotherapy tab's day link creates a chemotherapy admission listed on that tab" do
    day = Date.current + 9
    visit operations_calendar_path(start: day.iso8601, days: 1, view: "chemotherapy")
    within("tbody#day-#{day.iso8601}") { click_on "Reserve" }

    assert_current_path(/\/reservations\/new/)
    assert_equal "chemotherapy", find("#reservation_hospitalization_purpose").value
    assert_field "Scheduled procedure date", with: day.iso8601
    choose_protocol "Protocol A"
    choose_patient "H002 - Jane Smith"
    choose_diagnosis "Pneumonia"
    set_date "reservation_hospitalization_scheduled_admission_date", day

    assert_difference "Hospitalization.count", 1 do
      click_on "Register Reservation"
      assert_text "Reservation was successfully registered."
    end
    created = Hospitalization.order(:id).last
    assert_equal "chemotherapy", created.purpose
    assert_equal "Protocol A", created.chemotherapy_protocol.name

    visit operations_calendar_path(start: day.iso8601, days: 1, view: "chemotherapy")
    within("tbody#day-#{day.iso8601}") do
      assert_text "Jane Smith"
      assert_text "Protocol A"
    end
    visit operations_calendar_path(start: day.iso8601, days: 1, view: "examination")
    within("tbody#day-#{day.iso8601}") { assert_no_text "Jane Smith" }
  end

  test "errors show next to the fields and in a summary" do
    visit new_reservation_path(purpose: "surgery")

    click_on "Register Reservation"

    assert_selector "[role=alert]", text: "errors prohibited this reservation from being saved"
    assert_selector "p.text-error", text: /can't be blank|must exist/, minimum: 2
    assert_selector "#reservation-error-surgery-anesthesia_method, p.text-error", text: "can't be blank"
    assert_selector "input[aria-invalid=true]"
  end

  test "the performing department select appears only for locations that ask for one" do
    surgery_locations(:cath_lab).update!(asks_performing_department: true)
    visit new_reservation_path(purpose: "surgery")

    assert_no_select "Performing Department"
    select "Cath Lab", from: "Location / Setting"
    assert_select "Performing Department"
    select "Hybrid Room", from: "Location / Setting"
    assert_no_select "Performing Department"
  end

  test "the slot category chooses which surgery fields apply" do
    visit new_reservation_path(purpose: "surgery")

    assert_no_text "Intervention involved"
    assert_no_select "Partner Department"
    assert_select "Location / Setting"

    choose "Backup/Standby"
    assert_text "Intervention involved"
    assert_select "Partner Department"
    assert_no_select "Location / Setting"

    choose "Regular Slot"
    assert_no_text "Intervention involved"
    assert_select "Location / Setting"
  end

  test "changing the dates refreshes the admission count and the slot summary" do
    visit new_reservation_path(purpose: "surgery")

    assert_text "Enter a date to see that day's elective slots."
    set_date "reservation_surgery_surgery_date", Date.new(2026, 3, 3)
    assert_selector "turbo-frame#reservation_slot_summary", text: "2 / 3 slots"

    set_date "reservation_hospitalization_scheduled_admission_date", Date.new(2026, 3, 1)
    assert_selector "turbo-frame#reservation_admission_count", text: /Admissions already scheduled that day: \d+/
    assert_selector "turbo-frame#reservation_admission_calendar h3", text: "3/2026"
  end

  test "the side panel calendar pages through months" do
    visit new_reservation_path(purpose: "surgery")

    title = find("turbo-frame#reservation_admission_calendar h3").text
    find("a[aria-label='Next month']").click
    assert_no_selector "turbo-frame#reservation_admission_calendar h3", text: title, exact_text: true
    find("a[aria-label='Previous month']").click
    assert_selector "turbo-frame#reservation_admission_calendar h3", text: title, exact_text: true
  end

  test "the transfer source department is enabled only while a transfer status is chosen" do
    visit new_reservation_path(purpose: "surgery")

    assert_field "Source department", disabled: true
    choose "Transferred in"
    assert_field "Source department", disabled: false
    choose "No transfer"
    assert_field "Source department", disabled: true
  end

  test "a picked patient's card refreshes when the patient changes" do
    visit new_reservation_path(purpose: "surgery")

    assert_text "Pick a patient to confirm the chart."
    choose_patient "H001 - John Doe"
    within("[data-testid=patient-card]") { assert_text "H001" }
    choose_patient "H002 - Jane Smith"
    within("[data-testid=patient-card]") do
      assert_text "H002"
      assert_no_text "H001"
    end
  end

  test "a non-admin can register a new diagnosis from the picker while booking" do
    # The signed-in user (an admin) loses the role, so the same browser session is a regular user's.
    users(:admin).user_roles.where(role: "admin").delete_all
    assert_not users(:admin).reload.admin?
    visit new_reservation_path(purpose: "examination")

    click_on "Select Diagnosis", match: :first
    within("turbo-frame#diagnosis_picker_frame") do
      assert_text "Appendicitis"
      click_on "Register New Diagnosis"
      assert_field "Diagnosis Name"
      fill_in "Diagnosis Name", with: "Brand new diagnosis"
      click_on "Create Diagnosis"
    end
    assert_selector "turbo-frame#diagnosis_picker_frame", text: "Diagnosis was successfully created.", visible: :all
    assert_no_selector "dialog#diagnosis_picker_modal[open]"
    within(first("[data-hospitalization-diagnosis-fields-target='item']")) { assert_text "Brand new diagnosis" }
  end

  test "editing from the calendar row's patient name updates the surgery" do
    patient = patients(:two)
    Current.user = users(:admin)
    reservation = Reservation.new
    reservation.assign(
      hospitalization: { patient_id: patient.id, purpose: "surgery", scheduled_admission_date: @admission.iso8601 },
      surgery: { surgery_date: @surgery_date.iso8601, surgery_date_status: "scheduled", anesthesia_method: "Spinal" },
      diagnoses: { "0" => { diagnosis_id: diagnoses(:pneumonia).id, laterality: "none" } },
      procedures: { "0" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "none" } }
    )
    reservation.save!
    Current.reset

    visit operations_calendar_path(start: @surgery_date.iso8601, days: 1)
    within("tbody#day-#{@surgery_date.iso8601}") { click_on patient.name }

    assert_field "Anesthesia Method", with: "Spinal"
    fill_in "Anesthesia Method", with: "General anesthesia"
    click_on "Save Reservation"
    assert_text "Reservation was successfully updated."

    assert_equal "General anesthesia", reservation.surgery.reload.anesthesia_method
  end

  test "the team preview follows the chosen team and surgery date" do
    with_site_config("features" => { "teams" => true }) do
      visit new_reservation_path(purpose: "surgery")

      set_date "reservation_surgery_surgery_date", Date.new(2026, 10, 15)
      select "Blue Team", from: "Team"
      assert_selector "turbo-frame#reservation_team_members", text: "Alpha"
    end
  end

  test "the side panel sticks below the pinned navbar instead of sliding under it" do
    page.driver.browser.manage.window.resize_to(1400, 700)
    visit new_reservation_path
    page.execute_script("document.body.style.minHeight = '4000px'; document.querySelector('main, .app-main').style.minHeight = '4000px'; window.scrollTo(0, 1500)")
    rects = page.evaluate_script(<<~JS)
      (function () {
        var bar = document.querySelector('.app-navbar').getBoundingClientRect();
        var side = document.querySelector('aside').getBoundingClientRect();
        return { scrollY: window.scrollY, bar_top: bar.top, bar_bottom: bar.bottom, side_top: side.top };
      })()
    JS
    assert_operator rects["scrollY"], :>, 0
    assert_in_delta 0, rects["bar_top"], 1, "the navbar should be pinned"
    assert_operator rects["side_top"], :>=, rects["bar_bottom"] - 0.5, "the side panel must not be hidden under the navbar"
    page.save_screenshot(Rails.root.join("tmp/screenshots/reservation_side_panel_pinned.png"))
  end
end
