require "test_helper"

class ExportFieldTest < ActiveSupport::TestCase
  SURGERY_KEYS = %i[surgery_date weekday start_time slot_number slot_category scheduling_type hospital_id patient_name
                    patient_kana age sex diagnoses procedures surgical_device duration_hours anesthesia_method operator
                    assistant team team_members location performing_department partner_department backup_intervention
                    scheduled_admission_date admission_date discharge_date emergency_admission transfer_status
                    source_department referred_from adl reservation_doctor created_by submitted_on reservation_status
                    purpose clinical_comment].freeze
  HOSPITALIZATION_KEYS = %i[hospital_id patient_name patient_kana age sex diagnoses scheduled_admission_date admission_date
                            discharge_date emergency_admission transfer_status source_department referred_from adl
                            reservation_doctor created_by submitted_on reservation_status purpose clinical_comment
                            scheduled_procedure_date procedure_name planned_days scheduled_surgery_date attending_doctor
                            ward team team_members].freeze

  def value(subject, key, record)
    ExportField.find(subject, key).value(record)
  end

  def linked_surgery(**attrs)
    hospitalization = hospitalizations(:one)
    hospitalization.update_columns(attrs) if attrs.any?
    surgery = surgeries(:one)
    surgery.update_columns(hospitalization_id: hospitalization.id)
    surgery.reload
  end

  test "the registry knows every surgery and hospitalization field" do
    assert_equal SURGERY_KEYS.sort, ExportField.keys(:surgery).sort
    assert_equal HOSPITALIZATION_KEYS.sort, ExportField.keys(:hospitalization).sort
  end

  test "find raises for an unknown field" do
    assert_raises(KeyError) { ExportField.find(:surgery, :nope) }
    assert_raises(KeyError) { ExportField.find(:hospitalization, :surgery_date) }
  end

  test "every field has a header in English and Japanese" do
    %i[en ja].each do |locale|
      I18n.with_locale(locale) do
        ExportField.registry.each_value { |field| assert_not_includes field.header, "translation missing", "#{field.key} (#{locale})" }
      end
    end
  end

  test "team fields are the ones that need the teams feature" do
    assert_equal %i[team team_members], ExportField.registry.values.select(&:teams?).map(&:key).uniq.sort.map(&:to_sym)
  end

  # --- surgery values -----------------------------------------------------

  test "surgery fields read the surgery and its patient" do
    surgery = surgeries(:three)
    surgery.update_columns(operator_name: "Dr. Op", assistant_name: "Dr. As")
    assert_equal "2026-03-03", value(:surgery, :surgery_date, surgery)
    assert_equal "Tue", value(:surgery, :weekday, surgery)
    assert_equal "09:00", value(:surgery, :start_time, surgery)
    assert_equal "1", value(:surgery, :slot_number, surgery)
    assert_equal "Elective", value(:surgery, :scheduling_type, surgery)
    assert_equal "H001", value(:surgery, :hospital_id, surgery)
    assert_equal "John Doe", value(:surgery, :patient_name, surgery)
    assert_equal "46", value(:surgery, :age, surgery)
    assert_equal "1.0", value(:surgery, :duration_hours, surgery)
    assert_equal "General", value(:surgery, :anesthesia_method, surgery)
    assert_equal "Dr. Op", value(:surgery, :operator, surgery)
    assert_equal "Dr. As", value(:surgery, :assistant, surgery)
  end

  test "procedures and diagnoses carry laterality and are joined" do
    surgery = surgeries(:one)
    assert_equal "Right Appendectomy, Left Knee arthroscopy", value(:surgery, :procedures, surgery)
    assert_equal "Right Appendicitis", value(:surgery, :diagnoses, surgery)
  end

  test "the weekday follows the locale" do
    I18n.with_locale(:ja) { assert_equal "日", value(:surgery, :weekday, surgeries(:one)) }
  end

  test "an unset value is nil, not a dash" do
    surgery = surgeries(:one)
    assert_nil value(:surgery, :start_time, surgery)
    assert_nil value(:surgery, :slot_number, surgery)
    assert_nil value(:surgery, :surgical_device, surgery)
    assert_nil value(:surgery, :location, surgery)
    assert_nil value(:surgery, :performing_department, surgery)
    assert_nil value(:surgery, :backup_intervention, surgery)
    assert_nil value(:surgery, :operator, surgery)
  end

  test "hospitalization-side fields are nil for a surgery without a hospitalization" do
    surgery = surgeries(:one)
    %i[scheduled_admission_date admission_date discharge_date emergency_admission transfer_status source_department
       referred_from adl reservation_doctor created_by submitted_on reservation_status purpose clinical_comment].each do |key|
      assert_nil value(:surgery, key, surgery), key.to_s
    end
  end

  test "an undated surgery and one without a patient do not raise" do
    surgery = Surgery.new(slot_category: "regular", scheduling_type: "elective")
    ExportField.keys(:surgery).each { |key| assert_nothing_raised { value(:surgery, key, surgery) } }
    assert_nil value(:surgery, :surgery_date, surgery)
    assert_nil value(:surgery, :age, surgery)
    assert_nil value(:surgery, :hospital_id, surgery)
  end

  test "hospitalization-side fields read the linked hospitalization" do
    doctor = users(:member)
    surgery = linked_surgery(scheduled_admission_date: Date.new(2026, 2, 27), referred_from: "Clinic A", adl: "Independent",
                             reservation_doctor_id: doctor.id, created_by_id: users(:admin).id, submitted_on: Date.new(2026, 2, 20),
                             emergency_admission: true, clinical_comment: "Note")
    assert_equal "2026-02-27", value(:surgery, :scheduled_admission_date, surgery)
    assert_equal "2026-03-01", value(:surgery, :admission_date, surgery)
    assert_equal "2026-03-06", value(:surgery, :discharge_date, surgery)
    assert_equal "Clinic A", value(:surgery, :referred_from, surgery)
    assert_equal "Independent", value(:surgery, :adl, surgery)
    assert_equal doctor.name, value(:surgery, :reservation_doctor, surgery)
    assert_equal users(:admin).name, value(:surgery, :created_by, surgery)
    assert_equal "2026-02-20", value(:surgery, :submitted_on, surgery)
    assert_equal "Yes", value(:surgery, :emergency_admission, surgery)
    assert_equal "Note", value(:surgery, :clinical_comment, surgery)
    assert_equal "Surgery", value(:surgery, :purpose, surgery)
  end

  test "a discarded hospitalization is ignored" do
    surgery = linked_surgery(referred_from: "Clinic A")
    surgery.hospitalization.update_columns(deleted_at: Time.current)
    assert_nil value(:surgery, :referred_from, surgery.reload)
  end

  test "slot category, partner department and backup intervention" do
    surgery = surgeries(:one)
    surgery.update_columns(slot_category: "backup", backup_intervention: "involved", department_id: departments(:gynecology).id)
    assert_equal "Gynecology", value(:surgery, :partner_department, surgery)
    assert_equal "Backup/Standby", value(:surgery, :slot_category, surgery)
    assert_equal "Intervention involved", value(:surgery, :backup_intervention, surgery)
  end

  test "team values need the teams feature and use the effective team" do
    surgery = linked_surgery
    surgery.hospitalization.update_columns(team_id: teams(:blue).id)
    surgery.update_columns(surgery_date: Date.new(2026, 10, 19))
    surgery.reload
    assert_nil value(:surgery, :team, surgery)
    with_site_config("features" => { "teams" => true }) do
      assert_equal "Blue Team", value(:surgery, :team, surgery)
      assert_includes value(:surgery, :team_members, surgery), "Alpha"
    end
  end

  # --- hospitalization values ---------------------------------------------

  test "hospitalization fields read the hospitalization and its patient" do
    hospitalization = hospitalizations(:one)
    hospitalization.update_columns(purpose: "examination", scheduled_procedure_date: Date.new(2026, 3, 2), procedure_name: "Endoscopy",
                                   attending_doctor: "Dr. A", ward: "5A", transfer_status: "transferred_in")
    assert_equal "H001", value(:hospitalization, :hospital_id, hospitalization)
    assert_equal "46", value(:hospitalization, :age, hospitalization)
    assert_equal "2026-03-01", value(:hospitalization, :admission_date, hospitalization)
    assert_equal "Endoscopy", value(:hospitalization, :procedure_name, hospitalization)
    assert_equal "2026-03-02", value(:hospitalization, :scheduled_procedure_date, hospitalization)
    assert_equal "5", value(:hospitalization, :planned_days, hospitalization)
    assert_equal "Dr. A", value(:hospitalization, :attending_doctor, hospitalization)
    assert_equal "5A", value(:hospitalization, :ward, hospitalization)
    assert_equal "Examination / Procedure", value(:hospitalization, :purpose, hospitalization)
    assert_equal "Hypertension, Pneumonia".split(", ").sort, value(:hospitalization, :diagnoses, hospitalization).split(", ").sort
    assert_not_nil value(:hospitalization, :transfer_status, hospitalization)
  end

  test "hospitalization values are nil-safe" do
    hospitalization = Hospitalization.new
    ExportField.keys(:hospitalization).each { |key| assert_nothing_raised { value(:hospitalization, key, hospitalization) } }
    assert_nil value(:hospitalization, :age, hospitalization)
    assert_nil value(:hospitalization, :procedure_name, hospitalization)
  end

  test "an unset hospitalization date is blank" do
    assert_nil value(:hospitalization, :admission_date, hospitalizations(:four))
    assert_equal "2026-10-01", value(:hospitalization, :scheduled_admission_date, hospitalizations(:four))
  end

  test "includes_for lists the associations the fields read" do
    fields = %i[hospital_id diagnoses].map { |key| ExportField.find(:hospitalization, key) }
    assert_equal [ :patient, { hospitalization_diagnoses: :diagnosis } ], ExportField.includes_for(fields)
  end
end
