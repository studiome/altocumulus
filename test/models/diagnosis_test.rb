require "test_helper"

class DiagnosisTest < ActiveSupport::TestCase
  test "filtered treats wildcard characters literally" do
    literal = Diagnosis.create!(name: "Type_2 50% case")
    Diagnosis.create!(name: "TypeX2 500 case")

    assert_equal [ literal ], Diagnosis.filtered(keyword: "Type_2").to_a
    assert_equal [ literal ], Diagnosis.filtered(keyword: "50%").to_a
  end

  test "should be valid" do
    diagnosis = Diagnosis.new(name: "Gastritis")

    assert diagnosis.valid?
  end

  test "should require name" do
    diagnosis = Diagnosis.new(name: nil)

    assert_not diagnosis.valid?
  end

  test "should require unique name" do
    diagnosis = Diagnosis.new(name: diagnoses(:pneumonia).name)

    assert_not diagnosis.valid?
  end

  # AuditEventsHelper#audit_change_value resolves a "*_id" attribute to
  # `record.to_s` so the audit trail reads as a name instead of a raw id --
  # without this, a hospitalization/patient diagnosis change in the audit log
  # renders as Ruby's default "#<Diagnosis:0x...>" object inspection.
  test "to_s renders the diagnosis name" do
    assert_equal "Pneumonia", diagnoses(:pneumonia).to_s
  end

  test "filtered narrows the list by a case-insensitive partial name" do
    names = Diagnosis.filtered(keyword: "neumon").pluck(:name)

    assert_equal [ "Pneumonia" ], names
  end

  test "filtered returns every diagnosis when no keyword is given" do
    assert_equal Diagnosis.count, Diagnosis.filtered(keyword: nil).count
  end
end
