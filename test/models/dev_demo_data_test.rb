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

  # --- coherent clinical content ------------------------------------------------

  def run_demo(today: Date.new(2026, 10, 19), **options)
    DevDemoData.run(environment: "development", today: today, **options)
  end

  # The fixtures define their own places and departments; the builder's own
  # (surgery room, hybrid room, cath lab, cardiology...) are what these tests
  # are about.
  def use_demo_masters
    SurgeryLocation.delete_all
    Department.delete_all
  end

  def demo_hospitalizations
    Hospitalization.where("clinical_comment LIKE ?", "#{DevDemoData::MARKER} #%").includes(:patient, :surgeries)
  end

  def coherent_pairs
    DevDemoData::ALL_PAIRS.map { |pair| [ pair.diagnosis, pair.procedure ] }.to_set
  end

  test "every pair treats its own diagnosis" do
    DevDemoData::ALL_PAIRS.each do |pair|
      assert_not_equal pair.diagnosis, pair.procedure
      assert_equal pair.robotic, pair.procedure.start_with?("ロボット支援"), pair.procedure
      assert_equal :hybrid, pair.place, pair.procedure if pair.procedure.match?(/ステントグラフト|バイパス|大動脈弁/)
    end
    colorectal = DevDemoData::REGULAR_PAIRS.select { |pair| pair.diagnosis.match?(/大腸癌|直腸癌/) }
    assert colorectal.any? && colorectal.all?(&:robotic)
    assert DevDemoData::OFF_SLOT_PAIRS.all? { |pair| pair.place == :cath && pair.performer.present? }
    assert DevDemoData::REGULAR_PAIRS.select { |pair| pair.procedure.match?(/ヘルニア/) }.all? { |pair| pair.hours <= 1.5 }
    laterality = DevDemoData::ALL_PAIRS.select { |pair| pair.procedure.match?(/ヘルニア修復|腎部分切除|甲状腺葉|下肢動脈/) }
    assert laterality.all? { |pair| pair.dx_side != "none" && pair.proc_side == pair.dx_side }
  end

  test "the demo cases are coherent: diagnosis, procedure, laterality, device and place agree" do
    use_demo_masters
    run_demo
    cases = demo_hospitalizations.select { |hospitalization| hospitalization.surgeries.any? }
    assert_operator cases.size, :>=, 25

    cases.each do |hospitalization|
      surgery = hospitalization.surgeries.first
      diagnosis = hospitalization.hospitalization_diagnoses.first.diagnosis.name
      assert_equal [ diagnosis ], surgery.patient_diagnoses.map { |patient_diagnosis| patient_diagnosis.diagnosis.name }
      selection = surgery.surgery_procedure_selections.first
      side = surgery.patient_diagnoses.first.laterality
      pairs = DevDemoData::ALL_PAIRS.select do |candidate|
        candidate.diagnosis == diagnosis && candidate.procedure == selection.procedure_name && candidate.dx_side == side
      end
      assert pairs.any?, "#{diagnosis} (#{side}) with #{selection.procedure_name}"
      pair = pairs.find { |candidate| candidate.anesthesia == surgery.anesthesia_method && candidate.hours == surgery.duration_hours }
      assert pair, "#{selection.procedure_name}: #{surgery.anesthesia_method} #{surgery.duration_hours}h"
      assert_equal pair.proc_side, selection.laterality
      assert_equal pair.robotic, surgery.surgical_device.present?, selection.procedure_name
      # A joint or backup case sits in the partner department's slot, so the model keeps no location of ours.
      next if surgery.simultaneous_slot? || surgery.backup_slot?

      assert_equal({ main: "手術室", hybrid: "ハイブリッド室", cath: "カテ室" }.fetch(pair.place), surgery.surgery_location.name)
    end
  end

  test "examination and chemotherapy admissions carry a matching diagnosis and procedure" do
    run_demo
    demo_hospitalizations.reject { |hospitalization| hospitalization.surgeries.any? }.each do |hospitalization|
      diagnosis = hospitalization.hospitalization_diagnoses.first.diagnosis.name
      pair = DevDemoData::EXAM_PAIRS.find { |candidate| candidate.diagnosis == diagnosis }
      assert pair, diagnosis
      assert hospitalization.procedure_name.start_with?(pair.procedure), hospitalization.procedure_name
    end
  end

  test "the demo week shows an off-slot cath-lab case, a joint case, a backup with intervention and referral sources" do
    ElectiveSlotRule.delete_all
    use_demo_masters
    run_demo(today: Date.new(2026, 10, 16))
    week = Date.new(2026, 10, 19)..Date.new(2026, 10, 25)
    surgeries = Surgery.where(surgery_date: week, patient: Patient.where(name: DevDemoData::PATIENT_NAMES))

    off_slot = surgeries.where(slot_category: "off_slot").first
    assert off_slot
    assert_equal "カテ室", off_slot.surgery_location.name
    assert off_slot.performing_department
    assert surgeries.where(slot_category: "simultaneous").exists?
    assert surgeries.where(slot_category: "backup").where.not(backup_intervention: nil).exists?
    assert surgeries.emergency.exists?
    assert_operator surgeries.where(slot_category: "regular").count, :>=, 6
    assert_operator Hospitalization.where(id: surgeries.select(:hospitalization_id)).where.not(referred_from: nil).distinct.count(:referred_from), :>=, 2
  end

  # --- refresh --------------------------------------------------------------------

  test "a refresh run changes nothing when the demo rows are already current" do
    run_demo
    before = counts
    result = run_demo(refresh: true)
    assert_equal before, counts
    assert_equal 0, result[:refreshed_cases]
    assert_equal 0, run_demo(refresh: true)[:refreshed_cases]
  end

  test "a plain re-run leaves the demo rows alone, a refresh rewrites their clinical content" do
    run_demo
    hospitalization = demo_hospitalizations.find { |candidate| candidate.surgeries.any? }
    surgery = hospitalization.surgeries.first
    right_procedure = surgery.surgery_procedure_selections.first.procedure_name
    wrong = SurgeryProcedure.find_or_create_by!(name: "別の術式")
    surgery.surgery_procedure_selections.first.update!(surgery_procedure: wrong)
    surgery.update!(anesthesia_method: "局所麻酔", duration_hours: 9.0)
    hospitalization.patient.patient_diagnoses.first.update!(diagnosis: Diagnosis.find_or_create_by!(name: "別の診断"))
    hospitalization.update!(referred_from: "どこか")

    run_demo
    assert_equal "別の術式", surgery.reload.surgery_procedure_selections.first.procedure_name

    result = run_demo(refresh: true)
    assert_equal 1, result[:refreshed_cases]
    assert_equal right_procedure, surgery.reload.surgery_procedure_selections.first.procedure_name
    assert_not_equal 9.0, surgery.duration_hours
    assert_not_equal "別の診断", hospitalization.patient.patient_diagnoses.first.diagnosis.name
    assert_not_equal "どこか", hospitalization.reload.referred_from
    assert_equal 1, surgery.surgery_procedure_selections.count
  end

  test "a refresh only touches records of the demo task" do
    run_demo
    patient = Patient.create!(hospital_id: "55550001", name: "Real Patient", date_of_birth: Date.new(1970, 1, 1))
    diagnosis = Diagnosis.create!(name: "実在の診断")
    hospitalization = Hospitalization.create!(patient: patient, scheduled_admission_date: Date.new(2026, 10, 20), clinical_comment: "実際のメモ",
                                              referred_from: "実在の病院", hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnosis.id } ])
    snapshot = [ patient, hospitalization ].map { |record| record.reload.attributes }

    # A demo patient's own, non-demo hospitalization and a marker on a real patient.
    demo_patient = Patient.find_by!(hospital_id: "90000001")
    demo_patient.hospitalizations.where.not("clinical_comment LIKE ?", "#{DevDemoData::MARKER} #%").destroy_all
    impostor = Patient.create!(hospital_id: "55550002", name: "Marker Impostor", date_of_birth: Date.new(1971, 1, 1))
    impostor_hospitalization = Hospitalization.create!(patient: impostor, scheduled_admission_date: Date.new(2026, 10, 21),
                                                       clinical_comment: "#{DevDemoData::MARKER} #01", referred_from: "実在の紹介元",
                                                       hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnosis.id } ])
    impostor_snapshot = impostor_hospitalization.reload.attributes

    run_demo(refresh: true)

    assert_equal snapshot, [ patient, hospitalization ].map { |record| record.reload.attributes }
    assert_equal impostor_snapshot, impostor_hospitalization.reload.attributes
    assert_equal [ diagnosis.id ], hospitalization.hospitalization_diagnoses.pluck(:diagnosis_id)
  end
end
