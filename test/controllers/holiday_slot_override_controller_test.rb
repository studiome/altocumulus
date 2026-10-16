require "test_helper"

class HolidaySlotOverrideControllerTest < ActionDispatch::IntegrationTest
  DAY = "2026-03-17" # a Tuesday: 3 slots x 240 min

  test "the form offers the override fields with an explanation" do
    get new_holiday_url
    assert_select "input[name='holiday[slot_count]']"
    assert_select "input[name='holiday[slot_duration_minutes]']"
    assert_select ".app-helper", text: /overrides the weekday/i
  end

  test "create stores the override" do
    post holidays_url, params: { holiday: { date: DAY, holiday: "0", note: "Reduced", slot_count: "2.5", slot_duration_minutes: "120" } }

    holiday = Holiday.find_by!(date: DAY)
    assert_redirected_to holiday_url(holiday)
    assert_equal BigDecimal("2.5"), holiday.slot_count
    assert_equal 120, holiday.slot_duration_minutes
  end

  test "create rejects an override on a closed day" do
    assert_no_difference("Holiday.count") do
      post holidays_url, params: { holiday: { date: DAY, holiday: "1", name: "Closed", slot_count: "2" } }
    end
    assert_response :unprocessable_entity
  end

  test "show and index display the override" do
    Holiday.create!(date: DAY, holiday: false, note: "Reduced", slot_count: 2, slot_duration_minutes: 120)
    holiday = Holiday.find_by!(date: DAY)

    get holiday_url(holiday)
    assert_select "body", text: /Slot count/
    assert_select "span", text: "2"
    assert_select "span", text: /120/

    get holidays_url
    assert_select "td", text: /2 × 120 min/
  end

  test "the calendar day cell says when the override is in effect" do
    Holiday.create!(date: DAY, holiday: false, note: "Reduced", slot_count: 2)

    get operations_calendar_url, params: { start: DAY, days: 1 }
    assert_select "td.ledger-day", text: /Slots: 2 \(changed\)/

    get operations_calendar_url, params: { start: "2026-03-03", days: 1 }
    assert_select "td.ledger-day", text: /changed/, count: 0
  end

  test "the calendar day cell is in Japanese too" do
    Holiday.create!(date: DAY, holiday: false, note: "Reduced", slot_count: 2)
    sign_in_as(users(:japanese_member))

    get operations_calendar_url, params: { start: DAY, days: 1 }
    assert_select "td.ledger-day", text: /枠 2（変更）/
  end

  test "the surgery show page counts slots with the override" do
    Holiday.create!(date: DAY, holiday: false, note: "Reduced", slot_count: 2)
    surgery = Surgery.create!(
      patient: patients(:one), surgery_date: DAY, slot_number: 1, anesthesia_method: "General",
      surgery_procedure_selections_attributes: [ { surgery_procedure_id: surgery_procedures(:appendectomy).id } ]
    )

    get surgery_url(surgery)
    assert_select "span.badge", text: /1.*2/
  end
end
