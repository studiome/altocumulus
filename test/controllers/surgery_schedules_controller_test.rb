require "test_helper"

class SurgerySchedulesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get surgery_schedule_url
    assert_response :success
  end

  test "index does not error out on a crafted Array week_of param" do
    get surgery_schedule_url, params: { week_of: [ "2026-03-01" ] }
    assert_response :success
  end

  test "index defaults to the week containing today" do
    travel_to Date.new(2026, 3, 4) do # Wednesday
      get surgery_schedule_url
      assert_response :success
      assert_match(/2026-03-02/, @response.body) # Monday of that week
      assert_match(/2026-03-08/, @response.body) # Sunday of that week
    end
  end

  test "index accepts a week_of param and shows that week's Monday through Sunday" do
    get surgery_schedule_url, params: { week_of: "2026-03-03" } # a Tuesday
    assert_response :success
    assert_match(/2026-03-02/, @response.body)
    assert_match(/2026-03-08/, @response.body)
  end

  test "index links to the previous and next week" do
    get surgery_schedule_url, params: { week_of: "2026-03-03" }
    assert_response :success
    assert_select "a[href*='week_of=2026-02-23']"
    assert_select "a[href*='week_of=2026-03-09']"
  end

  test "index shows each slot with the surgeries booked into it and an unassigned section" do
    get surgery_schedule_url, params: { week_of: "2026-03-03" } # week of Mon 2026-03-02 .. Sun 2026-03-08
    assert_response :success
    assert_match(/Slot 1/, @response.body)
    assert_match(/Open/, @response.body)                    # slot 3 is empty
    assert_match(/Not assigned to a slot/, @response.body)  # surgeries(:six) has no slot yet
    assert_match(/Emergency/, @response.body)
  end

  test "index reports a slot's combined time rather than flagging each surgery" do
    get surgery_schedule_url, params: { week_of: "2026-03-03" }
    assert_response :success

    # Slot 1 holds two 60 min surgeries inside a 240 min slot, so it is fine;
    # slot 2 holds a single 300 min surgery, so the slot is 60 min over.
    assert_match(%r{120 / 240 min}, @response.body)
    assert_match(/\+60 min over/, @response.body)
    assert_no_match(/Extended/, @response.body)
  end

  test "index shows the emergency section, its start time, and unconfigured-day warnings for a week containing 2026-03-01" do
    get surgery_schedule_url, params: { week_of: "2026-02-25" } # week of Mon 2026-02-23 .. Sun 2026-03-01
    assert_response :success
    assert_match(/23:30/, @response.body)
    assert_match(/No elective slots are configured for Sunday/, @response.body)
  end

  test "index shows 'No slot available' instead of 'Over capacity' for an unconfigured day with an elective surgery" do
    get surgery_schedule_url, params: { week_of: "2026-02-25" } # week of Mon 2026-02-23 .. Sun 2026-03-01; Sunday has no slot rule and surgeries(:one) is elective
    assert_response :success
    assert_match(/No slot available/, @response.body)
    assert_no_match(/Over capacity/, @response.body)
  end

  test "index shows the holiday name and no-slots message for a week containing a holiday" do
    holiday = holidays(:national_holiday) # 2026-03-10, a Tuesday with a configured rule

    get surgery_schedule_url, params: { week_of: holiday.date.to_s }

    assert_response :success
    assert_match(/#{Regexp.escape(holiday.name)}/, @response.body)
    assert_match(/No elective slots \(holiday\)/, @response.body)
  end

  test "index shows a fractional slot_count as its whole number of slots, with a shortened last slot" do
    ElectiveSlotRule.find_by(day_of_week: Date.new(2026, 3, 3).wday).update!(slot_count: 2.5, slot_duration_minutes: 240)

    get surgery_schedule_url, params: { week_of: "2026-03-03" }

    assert_response :success
    assert_match(%r{/ 3 slots in use}, @response.body)
    assert_match(/Slot 3/, @response.body)
    assert_match(%r{0 / 120 min}, @response.body) # slot 3's own (shortened) duration, empty
  end

  test "index groups other-department and off-slot surgeries into their own sections" do
    simultaneous = create_week_surgery(slot_category: "simultaneous", target_department: "Gynecology")
    backup = create_week_surgery(slot_category: "backup", target_department: "Cardiovascular Surgery")
    off_slot = create_week_surgery(slot_category: "off_slot", location: "Cath Lab 1")

    get surgery_schedule_url, params: { week_of: "2026-03-03" }

    assert_response :success
    assert_no_match(/translation missing/, @response.body)
    assert_match(/Other Departments \(Joint \/ Backup\)/, @response.body)
    assert_match(/Off-slot \(Cath Lab, Procedure Room\)/, @response.body)
    assert_match(/Gynecology/, @response.body)
    assert_match(/Cardiovascular Surgery/, @response.body)
    assert_match(/Cath Lab 1/, @response.body)
    assert_select "a[href=?]", surgery_path(simultaneous)
    assert_select "a[href=?]", surgery_path(backup)
    assert_select "a[href=?]", surgery_path(off_slot)
  end

  test "index keeps other-department and off-slot surgeries out of the regular slot totals" do
    # Tuesday already books 420 of its 720 min across slots 1 and 2, with one
    # elective surgery still unassigned. A 180 min off-slot surgery on the same
    # day must not move that total, nor add to the unassigned warning.
    create_week_surgery(slot_category: "off_slot", location: "Cath Lab 1", duration_hours: 3.0)

    get surgery_schedule_url, params: { week_of: "2026-03-03" }

    assert_response :success
    assert_match(%r{\(420 / 720 min\)}, @response.body)
    assert_no_match(%r{\(600 / 720 min\)}, @response.body)
    assert_match(/1 elective surgery is not assigned to an available slot/, @response.body)
  end

  test "index labels an emergency surgery booked outside the regular slots" do
    emergency = surgeries(:emergency_one)
    emergency.update!(slot_category: "off_slot", location: "Cath Lab 1")

    get surgery_schedule_url, params: { week_of: "2026-02-25" } # week containing 2026-03-01

    assert_response :success
    assert_match(/Cath Lab 1/, @response.body)
    assert_select "a[href=?]", surgery_path(emergency)
  end

  test "index links to the holidays page" do
    get surgery_schedule_url
    assert_response :success
    assert_select "a[href=?]", holidays_path
  end

  private

    def create_week_surgery(slot_category:, target_department: nil, location: nil, duration_hours: 1.0)
      Surgery.create!(
        patient: patients(:one),
        surgery_date: Date.new(2026, 3, 3),
        scheduling_type: "elective",
        slot_category: slot_category,
        target_department: target_department,
        location: location,
        start_time: "09:00",
        anesthesia_method: "General",
        duration_hours: duration_hours,
        surgery_procedure_selections_attributes: [ { surgery_procedure_id: surgery_procedures(:appendectomy).id } ]
      )
    end
end
