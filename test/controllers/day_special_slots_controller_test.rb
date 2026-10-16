require "test_helper"

class DaySpecialSlotsControllerTest < ActionDispatch::IntegrationTest
  DATE = "2026-03-03".freeze # a Tuesday
  TURBO = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze
  CONTEXT = { start: "2026-03-01", days: "7", view: "surgery" }.freeze

  setup do
    @cath = surgery_locations(:cath_lab)
    @robot = surgical_devices(:robot_a)
  end

  def frame_headers
    { "Turbo-Frame" => "day-special-slots-#{DATE}" }
  end

  def counts(location: nil, device: nil)
    { special_slot_counts: { "SurgeryLocation" => { @cath.id.to_s => location }.compact, "SurgicalDevice" => { @robot.id.to_s => device }.compact } }
  end

  test "edit lists every active location and device with its weekly default as a hint" do
    SpecialSlotRule.create!(resource: @cath, day_of_week: 2, slot_count: 2)
    SpecialSlotDayOverride.create!(resource: @robot, date: DATE, slot_count: 1)

    get edit_day_special_slot_url(DATE), params: CONTEXT, headers: frame_headers

    assert_response :success
    assert_select "turbo-frame#day-special-slots-#{DATE}" do
      assert_select "form[action=?]", day_special_slot_path(DATE)
      assert_select "input[type=number][name=?][placeholder='2']", "special_slot_counts[SurgeryLocation][#{@cath.id}]"
      assert_select "input[type=number][name=?][value='1']", "special_slot_counts[SurgicalDevice][#{@robot.id}]"
      assert_select "input[type=number][min='0'][step='1']"
      assert_select "input[type=number]", SurgeryLocation.active.count + SurgicalDevice.active.count
      assert_select "input[type=hidden][name=start][value=?]", "2026-03-01"
    end
    assert_no_match(/Closed Room|Retired Robot/, response.body)
  end

  test "show closes the editor to an empty frame" do
    get day_special_slot_url(DATE), params: CONTEXT, headers: frame_headers
    assert_response :success
    assert_select "turbo-frame#day-special-slots-#{DATE}:empty"
  end

  test "update creates overrides, treats 0 as a real count, and re-renders the day" do
    assert_difference "SpecialSlotDayOverride.count", 2 do
      patch day_special_slot_url(DATE), params: CONTEXT.merge(counts(location: "0", device: "2")), headers: TURBO
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_equal [ 0, 2 ], [ SpecialSlotDayOverride.find_by!(resource: @cath, date: DATE).slot_count, SpecialSlotDayOverride.find_by!(resource: @robot, date: DATE).slot_count ]
    assert_select "turbo-stream[action=replace][target=day-#{DATE}]" do
      assert_select "template tbody#day-#{DATE} .special-slot-line", text: /Robot A 0\/2 lanes/
    end
  end

  test "update changes an existing override and a blank removes it" do
    SpecialSlotDayOverride.create!(resource: @cath, date: DATE, slot_count: 1)
    SpecialSlotDayOverride.create!(resource: @robot, date: DATE, slot_count: 1)

    assert_difference "SpecialSlotDayOverride.count", -1 do
      patch day_special_slot_url(DATE), params: CONTEXT.merge(counts(location: "3", device: "")), headers: TURBO
    end

    assert_equal 3, SpecialSlotDayOverride.find_by!(resource: @cath, date: DATE).slot_count
    assert_nil SpecialSlotDayOverride.find_by(resource: @robot, date: DATE)
  end

  test "a blank for a resource without an override changes nothing" do
    assert_no_difference "SpecialSlotDayOverride.count" do
      patch day_special_slot_url(DATE), params: CONTEXT.merge(counts(location: "", device: "")), headers: TURBO
    end
    assert_response :success
  end

  test "other dates' overrides are left alone" do
    other = SpecialSlotDayOverride.create!(resource: @cath, date: "2026-03-10", slot_count: 4)
    patch day_special_slot_url(DATE), params: CONTEXT.merge(counts(location: "1")), headers: TURBO
    assert_equal 4, other.reload.slot_count
  end

  test "invalid input renders inline errors with 422 and saves nothing, even for the valid rows" do
    assert_no_difference "SpecialSlotDayOverride.count" do
      patch day_special_slot_url(DATE), params: CONTEXT.merge(counts(location: "-1", device: "2")), headers: frame_headers
    end

    assert_response :unprocessable_entity
    assert_select "turbo-frame#day-special-slots-#{DATE} .alert-error"
    assert_select "input[name=?][value='-1']", "special_slot_counts[SurgeryLocation][#{@cath.id}]"
    assert_select "input[name=?][value='2']", "special_slot_counts[SurgicalDevice][#{@robot.id}]"
  end

  test "text and fractions are rejected" do
    [ "abc", "1.5" ].each do |value|
      patch day_special_slot_url(DATE), params: CONTEXT.merge(counts(location: value)), headers: frame_headers
      assert_response :unprocessable_entity
    end
    assert_equal 0, SpecialSlotDayOverride.count
  end

  test "unknown or inactive resources and unknown types are ignored" do
    params = { special_slot_counts: { "SurgeryLocation" => { surgery_locations(:closed_room).id.to_s => "1", "0" => "1" }, "Department" => { "1" => "1" } } }
    assert_no_difference "SpecialSlotDayOverride.count" do
      patch day_special_slot_url(DATE), params: CONTEXT.merge(params), headers: TURBO
    end
    assert_response :success
  end

  test "an inactive resource that already has an override on the day stays listed and editable" do
    SpecialSlotDayOverride.create!(resource: surgery_locations(:closed_room), date: DATE, slot_count: 1)
    get edit_day_special_slot_url(DATE), params: CONTEXT, headers: frame_headers
    assert_select "input[name=?][value='1']", "special_slot_counts[SurgeryLocation][#{surgery_locations(:closed_room).id}]"
  end

  test "a missing counts param is a no-op, not an error" do
    patch day_special_slot_url(DATE), params: CONTEXT, headers: TURBO
    assert_response :success
  end

  test "an invalid date is not found" do
    get edit_day_special_slot_url("not-a-date")
    assert_response :not_found
  end

  test "every action is admin only" do
    override = SpecialSlotDayOverride.create!(resource: @cath, date: DATE, slot_count: 1)
    sign_out
    sign_in_as(users(:member))

    get edit_day_special_slot_url(DATE)
    assert_redirected_to root_path
    get day_special_slot_url(DATE)
    assert_redirected_to root_path
    patch day_special_slot_url(DATE), params: counts(location: "")
    assert_redirected_to root_path
    assert_equal 1, override.reload.slot_count
  end
end
