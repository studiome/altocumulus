require "test_helper"
require "rake"

class DevDemoDataTest < ActiveSupport::TestCase
  COUNTED = [ User, Department, SurgeryLocation, SurgicalDevice, Team, TeamTerm, TeamTermMember, Patient,
              Hospitalization, Surgery, Holiday, ElectiveSlotRule, Diagnosis, SurgeryProcedure ].freeze

  def counts
    COUNTED.to_h { |model| [ model.name, model.count ] }
  end

  test "refuses to run outside development" do
    assert_raises(DevDemoData::NotDevelopmentError) { DevDemoData.run }
    assert_raises(DevDemoData::NotDevelopmentError) { DevDemoData.run(environment: "production") }
  end

  test "the rake task refuses outside development" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("dev:demo_data")
    task = Rake::Task["dev:demo_data"]
    task.reenable
    assert_no_difference -> { Patient.count } do
      assert_raises(DevDemoData::NotDevelopmentError) { capture_io { task.invoke } }
    end
  end

  test "creates the demo records" do
    before = counts
    result = DevDemoData.run(environment: "development", today: Date.new(2026, 10, 19))
    after = counts

    assert_operator after["User"] - before["User"], :>=, 10
    assert_operator after["Patient"] - before["Patient"], :>=, 30
    assert_operator after["Hospitalization"] - before["Hospitalization"], :>=, 30
    assert_operator after["Surgery"] - before["Surgery"], :>=, 25
    assert_operator after["Team"] - before["Team"], :>=, 3
    assert_equal 2 * (after["Team"] - before["Team"]), after["TeamTerm"] - before["TeamTerm"]
    assert_operator after["Holiday"] - before["Holiday"], :>=, 2
    assert Holiday.where.not(slot_count: nil).exists?
    assert_equal after["Surgery"] - before["Surgery"], result[:surgeries]

    demo_surgeries = Surgery.where(patient: Patient.where(name: DevDemoData::PATIENT_NAMES))
    assert demo_surgeries.emergency.exists?
    %w[simultaneous backup off_slot].each { |category| assert demo_surgeries.where(slot_category: category).exists?, category }
    assert demo_surgeries.where.not(surgical_device_id: nil).exists?
    assert demo_surgeries.where.not(performing_department_id: nil).exists?
    assert demo_surgeries.where.not(team_id: nil).exists?
    assert Hospitalization.where(emergency_admission: true).exists?
    assert Hospitalization.where.not(transfer_status: "none").exists?
    assert Hospitalization.where(purpose: "examination").where.not(procedure_name: nil).exists?
    assert Team.find_by!(name: DevDemoData::TEAMS.first[:name]).term_for(Date.new(2026, 10, 19))
  end

  test "is idempotent" do
    DevDemoData.run(environment: "development", today: Date.new(2026, 10, 19))
    before = counts
    DevDemoData.run(environment: "development", today: Date.new(2026, 10, 19))
    assert_equal before, counts
  end

  test "demo users can sign in with the shared password and demo patients have 8-digit ids" do
    DevDemoData.run(environment: "development", today: Date.new(2026, 10, 19))
    user = User.find_by!(login_id: DevDemoData::USERS.first[:login_id])
    assert user.authenticate("password")
    assert Patient.where(name: DevDemoData::PATIENT_NAMES).all? { |p| p.hospital_id.match?(/\A\d{8}\z/) }
  end
end
