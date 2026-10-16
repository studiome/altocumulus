require "test_helper"
require "rake"

class SiteMasterSeederTest < ActiveSupport::TestCase
  CONFIG = {
    "masters" => {
      "departments" => [ "Seed Dept A", "Gynecology", "Seed Dept B" ],
      "surgery_locations" => [ "Seed Room" ],
      "surgical_devices" => [ "Seed Device" ]
    }
  }.freeze

  test "creates missing names in listed order, appended after existing rows" do
    last_position = Department.maximum(:position)

    result = SiteMasterSeeder.call(SiteConfig.from_hash(CONFIG))

    a = Department.find_by!(name: "Seed Dept A")
    b = Department.find_by!(name: "Seed Dept B")
    assert_equal last_position + 1, a.position
    assert_equal last_position + 2, b.position
    assert a.active?
    assert SurgeryLocation.exists?(name: "Seed Room")
    assert SurgicalDevice.exists?(name: "Seed Device")
    assert_equal({ "departments" => 2, "surgery_locations" => 1, "surgical_devices" => 1 }, result)
  end

  test "is idempotent and never renames, reorders or reactivates existing rows" do
    existing = departments(:closed_department)
    before = existing.attributes
    config = SiteConfig.from_hash("masters" => { "departments" => [ existing.name, "Seed Dept A" ] })

    SiteMasterSeeder.call(config)
    assert_no_difference -> { Department.count } do
      assert_equal({ "departments" => 0, "surgery_locations" => 0, "surgical_devices" => 0 }, SiteMasterSeeder.call(config))
    end

    assert_equal before, existing.reload.attributes
  end

  test "never deletes rows that are not listed" do
    assert_difference -> { Department.count }, 1 do
      SiteMasterSeeder.call(SiteConfig.from_hash("masters" => { "departments" => [ "Only One" ] }))
    end
    assert Department.exists?(name: "Gynecology")
  end

  test "defaults to the current site config" do
    with_site_config(CONFIG) { SiteMasterSeeder.call }
    assert Department.exists?(name: "Seed Dept A")
  end

  test "an empty config does nothing" do
    assert_no_difference -> { Department.count + SurgeryLocation.count + SurgicalDevice.count } do
      SiteMasterSeeder.call(SiteConfig.from_hash({}))
    end
  end

  test "site:seed_masters rake task seeds from the current config and is idempotent" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("site:seed_masters")
    task = Rake::Task["site:seed_masters"]

    with_site_config(CONFIG) do
      assert_difference -> { Department.count }, 2 do
        capture_io { task.reenable; task.invoke }
      end
      assert_no_difference -> { Department.count } do
        capture_io { task.reenable; task.invoke }
      end
    end
  end
end
