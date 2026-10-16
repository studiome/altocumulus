require "test_helper"

# The weekly lane counts (列) a SurgeryLocation / SurgicalDevice may carry.
class SpecialSlotResourceTest < ActiveSupport::TestCase
  RESOURCES = { SurgeryLocation => :cath_lab, SurgicalDevice => :robot_a }.freeze

  RESOURCES.each do |klass, fixture|
    label = klass.name.underscore

    test "#{label}: without rules it is not a special slot resource" do
      record = send(klass.table_name, fixture)
      assert_not record.special_slot_resource?
      assert_equal({}, record.special_slot_counts)
    end

    test "#{label}: counts are set per weekday and read back" do
      record = send(klass.table_name, fixture)
      record.update!(special_slot_counts: { "1" => "2", "3" => "1", "5" => "" })
      record = klass.find(record.id)
      assert record.special_slot_resource?
      assert_equal({ 1 => 2, 3 => 1 }, record.special_slot_counts)
      assert_equal 2, record.special_slot_count_on(1)
      assert_equal 0, record.special_slot_count_on(2)
    end

    test "#{label}: blank or zero removes a weekday, and all-zero means not special" do
      record = send(klass.table_name, fixture)
      record.update!(special_slot_counts: { "1" => "2", "2" => "3" })
      record.update!(special_slot_counts: { "1" => "", "2" => "0" })
      record = klass.find(record.id)
      assert_equal({}, record.special_slot_counts)
      assert_not record.special_slot_resource?
      assert_equal 0, SpecialSlotRule.where(resource: record).count
    end

    test "#{label}: counts of a new record are saved with it, and a bad count is rejected" do
      record = klass.new(name: "Brand New", special_slot_counts: { "0" => "1" })
      assert record.save
      assert_equal({ 0 => 1 }, klass.find(record.id).special_slot_counts)

      bad = klass.new(name: "Bad One", special_slot_counts: { "0" => "-2" })
      assert_not bad.save
      worse = klass.new(name: "Worse One", special_slot_counts: { "0" => "abc" })
      assert_not worse.save
    end

    test "#{label}: leaving counts out of an update keeps the rules" do
      record = send(klass.table_name, fixture)
      record.update!(special_slot_counts: { "1" => "2" })
      klass.find(record.id).update!(name: "Renamed Resource")
      assert_equal({ 1 => 2 }, klass.find(record.id).special_slot_counts)
    end

    test "#{label}: destroying the record removes its rules" do
      record = klass.create!(name: "Doomed", special_slot_counts: { "1" => "2" })
      assert_difference("SpecialSlotRule.count", -1) { record.destroy }
    end
  end

  test "a department has no special slot counts" do
    assert_not Department.new.respond_to?(:special_slot_counts)
  end
end
