require "test_helper"

class CaseDatabaseFieldTest < ActiveSupport::TestCase
  setup do
    @field = case_database_fields(:notes)
  end

  test "valid fixture" do
    assert @field.valid?
  end

  test "requires a label" do
    @field.label = ""
    assert_not @field.valid?
  end

  test "requires a label unique within the case database" do
    duplicate = CaseDatabaseField.new(case_database: @field.case_database, label: @field.label, field_type: "text")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:label], "has already been taken"
  end

  test "allows the same label in a different case database" do
    other_db = CaseDatabase.create!(name: "Other Registry")
    other_field = CaseDatabaseField.new(case_database: other_db, label: @field.label, field_type: "text")
    assert other_field.valid?
  end

  test "requires field_type to be one of the known types" do
    @field.field_type = "bogus"
    assert_not @field.valid?
    assert_includes @field.errors[:field_type], "is not included in the list"
  end

  test "a select field requires at least one option" do
    field = CaseDatabaseField.new(case_database: @field.case_database, label: "Grade", field_type: "select", options: "")
    assert_not field.valid?
    assert_includes field.errors[:options], "can't be blank"
  end

  test "a select field is valid with at least one option" do
    field = CaseDatabaseField.new(case_database: @field.case_database, label: "Grade", field_type: "select", options: "A\nB")
    assert field.valid?
  end

  test "option_list strips whitespace, drops blanks, and uniqs" do
    field = case_database_fields(:outcome)
    field.options = " Good \n\nFair\nFair\n  \nPoor "
    assert_equal %w[Good Fair Poor], field.option_list
  end

  test "option_list is empty for a blank options string" do
    field = case_database_fields(:notes)
    assert_equal [], field.option_list
  end

  test "to_s returns the label" do
    assert_equal @field.label, @field.to_s
  end
end
