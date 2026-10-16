# Behavior shared by Department, SurgeryLocation and SurgicalDevice (see
# MasterRecord). Including tests define `master_class` and `used_fixture`
# (a fixture that a surgery references, see surgeries.yml) and `unused_name`.
module MasterRecordModelTests
  extend ActiveSupport::Concern

  included do
    test "name is required" do
      record = master_class.new(name: " ")
      assert_not record.valid?
      assert record.errors.of_kind?(:name, :blank)
    end

    test "name must be unique" do
      existing = master_class.first
      record = master_class.new(name: existing.name)
      assert_not record.valid?
      assert record.errors.of_kind?(:name, :taken)
    end

    test "name is stripped" do
      record = master_class.create!(name: "  #{unused_name}  ")
      assert_equal unused_name, record.name
    end

    test "active defaults to true" do
      assert master_class.new.active?
    end

    test "position is appended after the existing records when not given" do
      highest = master_class.maximum(:position)
      record = master_class.create!(name: unused_name)
      assert_equal highest + 1, record.position
    end

    test "an explicit position is kept" do
      record = master_class.create!(name: unused_name, position: 99)
      assert_equal 99, record.position
    end

    test "ordered sorts by position, then name" do
      first = master_class.create!(name: "Bb #{unused_name}", position: 0)
      second = master_class.create!(name: "Aa #{unused_name}", position: 0)

      assert_equal [ second, first ], master_class.ordered.first(2)
      positions = master_class.ordered.pluck(:position)
      assert_equal positions.sort, positions
    end

    test "active scope hides inactive records" do
      assert_includes master_class.active, master_class.find_by!(active: true)
      assert_empty master_class.active.where(active: false)
    end

    test "choices_for keeps an inactive record that the current one already uses" do
      inactive = master_class.find_by!(active: false)

      assert_not_includes master_class.choices_for(nil), inactive
      assert_includes master_class.choices_for(inactive.id), inactive
      assert_equal master_class.active.count + 1, master_class.choices_for(inactive.id).size
    end

    test "to_s is the name" do
      assert_equal master_class.first.name, master_class.first.to_s
    end

    test "a record in use cannot be destroyed" do
      record = used_fixture
      assert_no_difference "#{master_class}.count" do
        assert_not record.destroy
      end
      assert record.errors.any?
    end

    test "an unused record can be destroyed" do
      record = master_class.create!(name: unused_name)
      assert_difference("#{master_class}.count", -1) { record.destroy }
    end
  end
end
