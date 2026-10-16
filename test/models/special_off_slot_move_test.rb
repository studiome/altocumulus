require "test_helper"
require "rake"

# The one-off conversion of off-slot surgeries that name a special slot
# resource (a hybrid room, cath lab or robot) into regular-slot surgeries.
class SpecialOffSlotMoveTest < ActiveSupport::TestCase
  setup do
    SpecialSlotRule.create!(resource: surgery_locations(:hybrid_room), day_of_week: 2, slot_count: 1)
    SpecialSlotRule.create!(resource: surgical_devices(:robot_a), day_of_week: 3, slot_count: 1)
    SpecialSlotRule.create!(resource: surgery_locations(:cath_lab), day_of_week: 1, slot_count: 0) # zero: not special

    @hybrid = off_slot(:one, surgery_location: surgery_locations(:hybrid_room))
    @robot = off_slot(:two, surgical_device: surgical_devices(:robot_a))
    @plain_room = off_slot(:three, surgery_location: surgery_locations(:cath_lab))
    @no_resource = off_slot(:four)
    @emergency = off_slot(:emergency_one, surgery_location: surgery_locations(:hybrid_room))
    @regular_already = surgeries(:five)
    @regular_already.update!(surgery_location: surgery_locations(:hybrid_room))
  end

  def off_slot(name, **attributes)
    surgeries(name).tap { |surgery| surgery.update!(slot_category: "off_slot", **attributes) }
  end

  test "candidates are elective off-slot surgeries using a special resource" do
    assert_equal [ @hybrid.id, @robot.id ].sort, SpecialOffSlotMove.new.candidates.map(&:id).sort
  end

  test "a dry run lists what would change and changes nothing" do
    result = SpecialOffSlotMove.new(apply: false).run

    assert_equal 2, result.candidates.size
    assert_equal 0, result.moved
    assert_equal "off_slot", @hybrid.reload.slot_category
    assert_equal "off_slot", @robot.reload.slot_category
  end

  test "applying moves them to an unassigned regular slot and keeps their resources" do
    @hybrid.update_columns(slot_number: 2)
    result = SpecialOffSlotMove.new(apply: true).run

    assert_equal 2, result.moved
    [ @hybrid, @robot ].each do |surgery|
      surgery.reload
      assert_equal "regular", surgery.slot_category
      assert_nil surgery.slot_number
    end
    assert_equal surgery_locations(:hybrid_room), @hybrid.surgery_location
    assert_equal surgical_devices(:robot_a), @robot.surgical_device
  end

  test "a resource with only a per-date override counts as special; a zero override does not" do
    SpecialSlotDayOverride.create!(resource: surgery_locations(:closed_room), date: Date.new(2026, 3, 3), slot_count: 1)
    SpecialSlotDayOverride.create!(resource: surgery_locations(:cath_lab), date: Date.new(2026, 3, 3), slot_count: 0)
    only_override = off_slot(:six, surgery_location: surgery_locations(:closed_room))

    ids = SpecialOffSlotMove.new.candidates.map(&:id)
    assert_includes ids, only_override.id
    assert_not_includes ids, @plain_room.id
  end

  test "other surgeries are left alone" do
    SpecialOffSlotMove.new(apply: true).run

    assert_equal "off_slot", @plain_room.reload.slot_category
    assert_equal "off_slot", @no_resource.reload.slot_category
    assert_equal "off_slot", @emergency.reload.slot_category
    assert_equal [ "regular", 2 ], @regular_already.reload.then { |surgery| [ surgery.slot_category, surgery.slot_number ] }
  end

  test "it goes through the callbacks, so each move is audited" do
    assert_difference -> { AuditEvent.where(auditable_type: "Surgery", action: "update").count }, 2 do
      SpecialOffSlotMove.new(apply: true).run
    end
    event = AuditEvent.where(auditable_type: "Surgery", auditable_id: @hybrid.id).order(:id).last
    assert_equal [ "off_slot", "regular" ], event.change_data["slot_category"]
  end

  test "running it again changes nothing" do
    SpecialOffSlotMove.new(apply: true).run
    assert_no_difference "AuditEvent.count" do
      assert_equal 0, SpecialOffSlotMove.new(apply: true).run.moved
    end
  end

  test "a surgery that cannot be saved is reported and the rest still move" do
    @hybrid.update_columns(anesthesia_method: nil) # fails Surgery's own validation
    result = SpecialOffSlotMove.new(apply: true).run

    assert_equal 1, result.moved
    assert_equal [ @hybrid.id ], result.failed.map(&:first)
    assert_equal "off_slot", @hybrid.reload.slot_category
    assert_equal "regular", @robot.reload.slot_category
  end

  # --- the rake task ------------------------------------------------------

  def run_task(env = {})
    Rails.application.load_tasks unless Rake::Task.task_defined?("surgeries:move_special_off_slot_to_regular")
    task = Rake::Task["surgeries:move_special_off_slot_to_regular"]
    task.reenable
    previous = ENV.to_h.slice(*env.keys)
    env.each { |key, value| ENV[key] = value }
    out, = capture_io { task.invoke }
    out
  ensure
    env.each_key { |key| ENV.delete(key) }
    previous&.each { |key, value| ENV[key] = value }
  end

  test "the task is a dry run by default and lists id, date, hospital id and resource" do
    out = run_task

    assert_includes out, "DRY RUN"
    assert_includes out, "##{@hybrid.id}"
    assert_includes out, @hybrid.surgery_date.to_s
    assert_includes out, @hybrid.patient.hospital_id
    assert_includes out, "Hybrid Room"
    assert_includes out, "Robot A"
    assert_equal "off_slot", @hybrid.reload.slot_category
  end

  test "APPLY=1 performs the move" do
    out = run_task("APPLY" => "1")

    assert_includes out, "moved: 2"
    assert_equal "regular", @hybrid.reload.slot_category
  end

  test "DRY_RUN=1 wins over APPLY=1" do
    run_task("APPLY" => "1", "DRY_RUN" => "1")
    assert_equal "off_slot", @hybrid.reload.slot_category
  end
end
