require "test_helper"

# Stage 3 fields: emergency admission, transfer status, reservation doctor as a
# user, who entered the record, and the non-surgery procedure schedule.
class HospitalizationWorkflowFieldsTest < ActiveSupport::TestCase
  setup do
    @hospitalization = hospitalizations(:one)
  end

  def build(**attrs)
    Hospitalization.new(
      patient: patients(:two), scheduled_admission_date: Date.new(2027, 1, 10), reason: "r",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ], **attrs
    )
  end

  test "emergency_admission defaults to false and is not null" do
    assert_equal false, Hospitalization.new.emergency_admission
    @hospitalization.emergency_admission = nil
    assert_raises(ActiveRecord::NotNullViolation) { @hospitalization.save!(validate: false) }
  end

  test "transfer_status defaults to none, and options are localized" do
    assert_equal "none", Hospitalization.new.transfer_status
    assert_equal %w[none transferred_in operated_without_transfer], Hospitalization::TRANSFER_STATUS_KEYS
    assert_equal "他科から転科して入院", I18n.with_locale(:ja) { Hospitalization.transfer_status_options["transferred_in"] }
    assert_equal [ "No transfer", "none" ], Hospitalization.transfer_status_form_options.first
  end

  test "transfer_status must be a known key" do
    @hospitalization.transfer_status = "bogus"
    assert_not @hospitalization.valid?
    assert @hospitalization.errors.key?(:transfer_status)
  end

  test "source department is required when a transfer status is set" do
    %w[transferred_in operated_without_transfer].each do |status|
      @hospitalization.transfer_status = status
      @hospitalization.source_department = nil
      assert_not @hospitalization.valid?, status
      assert @hospitalization.errors.key?(:source_department)
    end
    @hospitalization.source_department = departments(:gynecology)
    assert @hospitalization.valid?
  end

  test "source department is cleared when the transfer status becomes none" do
    @hospitalization.update!(transfer_status: "transferred_in", source_department: departments(:gynecology))
    @hospitalization.update!(transfer_status: "none")
    assert_nil @hospitalization.reload.source_department_id
  end

  test "reservation_doctor_display prefers the user, then the legacy name" do
    assert_nil @hospitalization.reservation_doctor_display
    @hospitalization.reservation_doctor_legacy_name = "Dr. Old"
    assert_equal "Dr. Old", @hospitalization.reservation_doctor_display
    @hospitalization.reservation_doctor = users(:member)
    assert_equal "Member User", @hospitalization.reservation_doctor_display
  end

  test "choosing a reservation doctor drops the legacy name" do
    @hospitalization.update!(reservation_doctor_legacy_name: "Dr. Old")
    @hospitalization.update!(reservation_doctor: users(:member))
    assert_nil @hospitalization.reload.reservation_doctor_legacy_name
  end

  test "created_by is set from Current.user on create only" do
    Current.user = users(:member)
    record = build
    record.save!
    assert_equal users(:member), record.created_by

    Current.user = users(:admin)
    record.update!(reason: "changed")
    assert_equal users(:member), record.reload.created_by
  ensure
    Current.reset
  end

  test "created_by is nil without a Current.user and ignores a mass-assigned value" do
    Current.reset
    record = build(discharge_date: Date.new(2027, 1, 12), outcome: "recovered")
    record.save!
    assert_nil record.created_by

    Current.user = users(:member)
    forged = build(created_by_id: users(:admin).id, scheduled_admission_date: Date.new(2027, 3, 1))
    forged.save!
    assert_equal users(:member), forged.created_by
  ensure
    Current.reset
  end

  test "rebook records the rebooking user as creator and drops the procedure date" do
    original = hospitalizations(:two)
    original.update!(scheduled_procedure_date: Date.new(2026, 3, 5))
    Current.user = users(:admin)
    copy = original.rebook(scheduled_admission_date: Date.new(2027, 5, 1))
    assert_equal users(:admin), copy.created_by
    assert_nil copy.scheduled_procedure_date
  ensure
    Current.reset
  end

  test "scheduled_procedure_date may not precede the scheduled admission date" do
    record = build(scheduled_procedure_date: Date.new(2027, 1, 9))
    assert_not record.valid?
    assert record.errors.key?(:scheduled_procedure_date)
    record.scheduled_procedure_date = Date.new(2027, 1, 10)
    assert record.valid?
    record.scheduled_procedure_date = nil
    assert record.valid?
  end

  test "an unparsable scheduled_procedure_date is an error" do
    record = build(scheduled_procedure_date: "not a date")
    assert_not record.valid?
    assert record.errors.key?(:scheduled_procedure_date)
  end
end

class HospitalizationPurposeRequiredFieldsTest < ActiveSupport::TestCase
  CONFIG = {
    "required_fields" => {
      "hospitalization" => %w[referred_from],
      "hospitalization_by_purpose" => { "examination" => %w[scheduled_procedure_date procedure_name] }
    }
  }.freeze

  def build(purpose, **attrs)
    Hospitalization.new(
      patient: patients(:two), scheduled_admission_date: Date.new(2027, 1, 10), purpose: purpose, reason: "r",
      referred_from: "Clinic", hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ], **attrs
    )
  end

  test "purpose fields are required only for that purpose" do
    with_site_config(CONFIG) do
      exam = build("examination")
      assert_not exam.valid?
      assert exam.errors.key?(:scheduled_procedure_date)
      assert exam.errors.key?(:procedure_name)

      assert build("surgery").valid?
      assert build("examination", scheduled_procedure_date: Date.new(2027, 1, 11), procedure_name: "Colonoscopy").valid?
    end
  end

  test "required_attribute? takes the record or the purpose into account" do
    with_site_config(CONFIG) do
      assert Hospitalization.required_attribute?(:referred_from)
      assert_not Hospitalization.required_attribute?(:procedure_name)
      assert Hospitalization.required_attribute?(:procedure_name, build("examination"))
      assert_not Hospitalization.required_attribute?(:procedure_name, build("surgery"))
      assert Hospitalization.required_attribute?(:procedure_name, purpose: "examination")
      assert_not Hospitalization.required_attribute?(:procedure_name, purpose: "other")
      assert Hospitalization.required_attribute?(:referred_from, build("surgery"))
    end
  end
end
