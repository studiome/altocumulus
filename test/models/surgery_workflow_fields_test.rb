require "test_helper"

# Stage 3 surgery fields: the hospitalization a surgery belongs to, the backup
# intervention answer and the performing department.
class SurgeryWorkflowFieldsTest < ActiveSupport::TestCase
  setup do
    @surgery = surgeries(:one)
  end

  test "hospitalization is optional" do
    assert_nil @surgery.hospitalization
    assert @surgery.valid?
  end

  test "the linked hospitalization must belong to the surgery's patient" do
    @surgery.hospitalization = hospitalizations(:two) # patient two; the surgery is patient one's
    assert_not @surgery.valid?
    assert @surgery.errors.key?(:hospitalization)

    @surgery.hospitalization = hospitalizations(:one)
    assert @surgery.valid?
  end

  test "changing the patient of a linked surgery drops the stale link" do
    @surgery.update!(hospitalization: hospitalizations(:one))
    @surgery.update!(patient: patients(:two), patient_diagnosis_ids: [])
    assert_nil @surgery.reload.hospitalization_id
  end

  test "hospitalization has many surgeries and nullifies them if it goes away" do
    hospitalization = hospitalizations(:one)
    @surgery.update!(hospitalization: hospitalization)
    assert_includes hospitalization.surgeries, @surgery
    hospitalization.destroy
    assert_nil @surgery.reload.hospitalization_id
  end

  test "backup_intervention keys are localized" do
    assert_equal %w[involved not_involved], Surgery::BACKUP_INTERVENTION_KEYS
    assert_equal({ "involved" => "介入あり", "not_involved" => "介入なし" }, I18n.with_locale(:ja) { Surgery.backup_intervention_options })
    assert_equal [ [ "Intervention involved", "involved" ], [ "No intervention", "not_involved" ] ], Surgery.backup_intervention_form_options
  end

  test "a backup surgery requires backup_intervention" do
    @surgery.slot_category = "backup"
    assert_not @surgery.valid?
    assert @surgery.errors.of_kind?(:backup_intervention, :blank)

    @surgery.backup_intervention = "bogus"
    assert_not @surgery.valid?
    assert @surgery.errors.of_kind?(:backup_intervention, :inclusion)

    @surgery.backup_intervention = "not_involved"
    assert @surgery.valid?
  end

  test "backup_intervention is cleared for any other slot category" do
    @surgery.update!(slot_category: "backup", backup_intervention: "involved")
    @surgery.update!(slot_category: "regular")
    assert_nil @surgery.reload.backup_intervention

    @surgery.backup_intervention = "involved"
    assert @surgery.valid?
    assert_nil @surgery.backup_intervention
  end

  test "performing_department is optional and unaffected by the slot category" do
    @surgery.update!(performing_department: departments(:gynecology))
    @surgery.update!(slot_category: "off_slot")
    assert_equal departments(:gynecology), @surgery.reload.performing_department
  end

  test "a department in use as a transfer source or performing department cannot be deleted" do
    department = departments(:gynecology)
    @surgery.update!(performing_department: department)
    assert_not department.destroy
    assert department.errors.any?
    @surgery.update!(performing_department: nil)

    hospitalizations(:one).update!(transfer_status: "transferred_in", source_department: department)
    assert_not department.reload.destroy
  end
end
