require "test_helper"

class CaseDatabaseEntryTest < ActiveSupport::TestCase
  setup do
    @entry = case_database_entries(:one)
    @notes_field = case_database_fields(:notes)
    @number_field = case_database_fields(:ejection_fraction)
    @select_field = case_database_fields(:outcome)
  end

  test "valid fixture" do
    assert @entry.valid?
  end

  test "a patient can only be added to the same case database once" do
    duplicate = CaseDatabaseEntry.new(case_database: @entry.case_database, patient: @entry.patient)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:patient_id], "has already been taken"
  end

  test "the same patient can be added to a different case database" do
    other_db = CaseDatabase.create!(name: "Other Registry")
    entry = CaseDatabaseEntry.new(case_database: other_db, patient: @entry.patient)
    assert entry.valid?
  end

  test "value_for reads the stored value by field id" do
    @entry.field_values = { @notes_field.id.to_s => "Improving" }
    assert_equal "Improving", @entry.value_for(@notes_field)
  end

  test "value_for returns nil when the field has no stored value" do
    assert_nil @entry.value_for(@notes_field)
  end

  test "a blank value is allowed for a number field" do
    @entry.field_values = { @number_field.id.to_s => "" }
    assert @entry.valid?
  end

  test "a non-blank numeric value is valid for a number field" do
    @entry.field_values = { @number_field.id.to_s => "55.5" }
    assert @entry.valid?
  end

  test "a non-numeric value is invalid for a number field" do
    @entry.field_values = { @number_field.id.to_s => "not-a-number" }
    assert_not @entry.valid?
    assert_not_empty @entry.errors[:field_values]
  end

  test "a blank value is allowed for a select field" do
    @entry.field_values = { @select_field.id.to_s => "" }
    assert @entry.valid?
  end

  test "a value in the option list is valid for a select field" do
    @entry.field_values = { @select_field.id.to_s => "Good" }
    assert @entry.valid?
  end

  test "a value outside the option list is invalid for a select field" do
    @entry.field_values = { @select_field.id.to_s => "Excellent" }
    assert_not @entry.valid?
    assert_not_empty @entry.errors[:field_values]
  end

  test "assign_field_values merges into existing values and ignores unknown field ids" do
    @entry.field_values = { @notes_field.id.to_s => "Old note" }
    @entry.assign_field_values({ @number_field.id.to_s => "60", "999999" => "ignored" })

    assert_equal "Old note", @entry.value_for(@notes_field)
    assert_equal "60", @entry.value_for(@number_field)
    assert_nil @entry.field_values["999999"]
  end
end
