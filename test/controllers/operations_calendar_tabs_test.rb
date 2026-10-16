require "test_helper"

# The operations calendar's two tabs (surgery / examination admission), the
# row styling and legend, the day cell, the day-note band and the filters.
class OperationsCalendarTabsTest < ActionDispatch::IntegrationTest
  RANGE = { start: "2026-03-01", days: 7 }.freeze

  test "an accessible tablist offers both tabs, surgery by default, and keeps the range" do
    get operations_calendar_url, params: RANGE
    assert_select "[role=tablist].print\\:hidden" do
      assert_select "a[role=tab][aria-selected=true]", text: "Surgery", count: 1
      assert_select "a[role=tab][aria-selected=false]", text: "Examination admission", count: 1
      assert_select "a[role=tab][href=?]", operations_calendar_path(start: "2026-03-01", days: 7, view: "examination")
    end
    assert_select "[role=tabpanel][aria-labelledby]"
  end

  test "an unknown view falls back to surgery" do
    get operations_calendar_url, params: RANGE.merge(view: "bogus")
    assert_select "a[role=tab][aria-selected=true]", text: "Surgery"
  end

  test "the range form keeps the view and the filters" do
    with_site_config("features" => { "teams" => true }) do
      get operations_calendar_url, params: RANGE.merge(view: "examination", mine: "1", team_id: teams(:blue).id)
    end
    assert_select "form[action=?]", operations_calendar_path do
      assert_select "input[type=hidden][name=view][value=examination]"
      assert_select "input[type=checkbox][name=mine][checked]"
      assert_select "select[name=team_id] option[selected]", text: "Blue Team"
    end
    assert_select "a[role=tab][href*='mine=1']", count: 2
  end

  test "the team select only exists with the teams feature" do
    get operations_calendar_url, params: RANGE
    assert_select "select[name=team_id]", false
    assert_select "input[type=checkbox][name=mine]"
  end

  test "emergency rows get the urgent style and a stripe, off-slot categories are hatched" do
    surgeries(:one).update_columns(slot_category: "simultaneous")
    surgeries(:two).update_columns(slot_category: "off_slot", scheduling_type: "emergency")
    get operations_calendar_url, params: RANGE
    assert_select "tr.ledger-row-urgent.ledger-row-emergency", minimum: 1
    assert_select "tr.ledger-row-offslot", minimum: 2
    assert_select "tr.ledger-row-offslot:not(.ledger-row-emergency) td.ledger-stripe", false
    assert_select "tr.ledger-row-emergency td.ledger-stripe", minimum: 1
  end

  test "a regular elective row has neither marker" do
    get operations_calendar_url, params: { start: "2026-03-03", days: 1 }
    assert_select "tr.oc-surgery.ledger-row-offslot", false
    assert_select "tr.oc-surgery.ledger-row-emergency", false
  end

  test "the legend explains the row styling and stays in print" do
    get operations_calendar_url, params: RANGE
    assert_select ".oc-legend" do
      assert_select ".oc-legend-emergency"
      assert_select ".oc-legend-offslot"
      assert_select ".oc-legend-note"
    end
    assert_select ".oc-legend.print\\:hidden", false
    get operations_calendar_url, params: RANGE.merge(view: "examination")
    assert_select ".oc-legend", false
  end

  test "the day cell shows slots with a changed marker, minutes (red when over) and admissions" do
    Holiday.create!(date: Date.new(2026, 3, 3), holiday: false, note: "Short day", slot_count: 2)
    get operations_calendar_url, params: { start: "2026-03-03", days: 1 }
    assert_select "tbody#day-2026-03-03 td.ledger-day" do
      assert_select "*", text: /2 \/ 2 slots/
      assert_select "*", text: /\(changed\)/
      assert_select ".text-error", text: /\d+ \/ 480 min/
    end
    assert_select "tbody#day-2026-03-03 td.ledger-day a[href=?]", new_reservation_path(surgery_date: "2026-03-03", purpose: "surgery"), minimum: 2
  end

  test "minutes are not red within capacity" do
    get operations_calendar_url, params: { start: "2026-03-02", days: 1 }
    assert_select "tbody#day-2026-03-02 td.ledger-day .text-error", false
  end

  # --- day note band ---------------------------------------------------------

  test "the band shows the closed day, the note and the slot override" do
    get operations_calendar_url, params: { start: "2026-03-10", days: 1 }
    assert_select "tr.ledger-band", text: /Vernal Equinox Day/

    Holiday.create!(date: Date.new(2026, 3, 4), holiday: false, note: "Staff meeting", slot_count: 2)
    get operations_calendar_url, params: { start: "2026-03-04", days: 1 }
    assert_select "tr.ledger-band", text: /Staff meeting/
    assert_select "tr.ledger-band", text: /Slots 2/
  end

  test "admins get edit and add controls aimed at the day's frame" do
    get operations_calendar_url, params: { start: "2026-03-10", days: 2 }
    assert_select "turbo-frame#day-note-2026-03-10 a[href^=?][data-turbo-frame=?]", edit_day_note_path("2026-03-10"), "day-note-2026-03-10", text: "Edit"
    assert_select "tbody#day-2026-03-11 a[href^=?][data-turbo-frame=?]", edit_day_note_path("2026-03-11"), "day-note-2026-03-11", text: "Add note"
    assert_select "tbody#day-2026-03-11 turbo-frame#day-note-2026-03-11"
  end

  test "non-admins see the band read-only and no edit controls" do
    sign_out
    sign_in_as(users(:member))
    get operations_calendar_url, params: { start: "2026-03-10", days: 2 }
    assert_select "tr.ledger-band", text: /Vernal Equinox Day/
    assert_select "a[href*='day_notes']", false
    assert_select "tbody#day-2026-03-11 turbo-frame", false
  end

  # --- examination tab ---------------------------------------------------------

  def make_examination(hospitalization, date)
    hospitalization.update_columns(purpose: "examination", scheduled_procedure_date: date, scheduled_admission_date: date, admission_date: nil, discharge_date: nil)
  end

  test "the examination tab lists non-surgery admissions under their day with links" do
    hospitalization = hospitalizations(:two)
    make_examination(hospitalization, Date.new(2026, 5, 12))
    get operations_calendar_url, params: { start: "2026-05-11", days: 3, view: "examination" }
    assert_response :success
    assert_select "tbody#day-2026-05-12 tr.oc-exam", 1
    assert_select "tbody#day-2026-05-12 a[href=?]", hospitalization_path(hospitalization)
    assert_select "tbody#day-2026-05-12 a[href=?]", edit_reservation_path(hospitalization)
    assert_select "tbody#day-2026-05-12 td.ledger-day" do
      assert_select "a[href=?]", new_reservation_path(purpose: "examination", scheduled_procedure_date: "2026-05-12"), text: I18n.t("reservations.links.new_reservation")
      assert_select "*", text: /Admissions:/
    end
    assert_select "tbody#day-2026-05-11 tr.oc-empty", text: /No examination admissions/
    assert_select ".oc-day", 3
  end

  test "the examination tab uses the configured columns" do
    make_examination(hospitalizations(:two), Date.new(2026, 5, 12))
    with_site_config("ledger_columns" => { "examination_calendar" => %w[patient purpose] }) do
      get operations_calendar_url, params: { start: "2026-05-12", days: 1, view: "examination" }
    end
    assert_select "thead th", 3
  end

  test "an invalid range on the examination tab redirects like the surgery tab" do
    get operations_calendar_url, params: { view: "examination", days: "999" }
    assert_redirected_to operations_calendar_path
  end

  test "the mine filter narrows the examination tab" do
    make_examination(hospitalizations(:two), Date.new(2026, 5, 12))
    make_examination(hospitalizations(:one), Date.new(2026, 5, 12))
    hospitalizations(:two).update_columns(reservation_doctor_id: users(:admin).id)
    get operations_calendar_url, params: { start: "2026-05-12", days: 1, view: "examination", mine: "1" }
    assert_select "tr.oc-exam", 1
    assert_select "tr.oc-exam a[href=?]", hospitalization_path(hospitalizations(:two))
  end

  test "the mine filter narrows the surgery tab but keeps the day's slot summary" do
    hospitalization = hospitalizations(:one)
    surgeries(:three).update_columns(hospitalization_id: hospitalization.id)
    hospitalization.update_columns(reservation_doctor_id: users(:admin).id)
    get operations_calendar_url, params: { start: "2026-03-03", days: 1, mine: "1" }
    assert_select "tr.oc-surgery", 1
    assert_select "td.ledger-day", text: /2 \/ 3 slots/
  end

  test "the examination tab query count does not grow with rows" do
    make_examination(hospitalizations(:two), Date.new(2026, 5, 12))
    few = request_query_count { get operations_calendar_url, params: { start: "2026-05-11", days: 5, view: "examination" } }
    make_examination(hospitalizations(:one), Date.new(2026, 5, 13))
    make_examination(hospitalizations(:three), Date.new(2026, 5, 13))
    make_examination(hospitalizations(:four), Date.new(2026, 5, 14))
    many = request_query_count { get operations_calendar_url, params: { start: "2026-05-11", days: 5, view: "examination" } }
    assert_equal few, many
  end

  private

    def request_query_count
      count = 0
      counter = ->(_n, _s, _f, _i, payload) { count += 1 unless payload[:cached] || payload[:name] == "SCHEMA" }
      ActiveRecord::Base.uncached { ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield } }
      count
    end
end
