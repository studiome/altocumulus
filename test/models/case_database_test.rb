require "test_helper"

class CaseDatabaseTest < ActiveSupport::TestCase
  setup do
    @case_database = case_databases(:registry)
  end

  test "valid fixture" do
    assert @case_database.valid?
  end

  test "requires a name" do
    @case_database.name = ""
    assert_not @case_database.valid?
    assert_includes @case_database.errors[:name], "can't be blank"
  end

  test "requires a unique name" do
    duplicate = CaseDatabase.new(name: @case_database.name)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "to_s returns the name" do
    assert_equal @case_database.name, @case_database.to_s
  end

  test "fields are ordered by position then id" do
    assert_equal %w[Notes], [ @case_database.fields.first.label ]
    assert_equal [ "Notes", "Ejection Fraction", "Outcome" ], @case_database.fields.map(&:label)
  end

  test "destroying a case database destroys its fields and entries" do
    field_ids = @case_database.fields.pluck(:id)
    entry_ids = @case_database.entries.pluck(:id)

    @case_database.destroy

    assert_empty CaseDatabaseField.where(id: field_ids)
    assert_empty CaseDatabaseEntry.where(id: entry_ids)
  end

  test "records an audit event on create" do
    assert_difference("AuditEvent.count", 1) do
      CaseDatabase.create!(name: "New Registry")
    end
  end

  test "to_csv includes a BOM, header, and one row per entry ordered by hospital_id" do
    entry = case_database_entries(:one)
    notes_field = case_database_fields(:notes)
    entry.update!(field_values: { notes_field.id.to_s => "Doing well" })

    csv = @case_database.to_csv

    assert csv.start_with?("﻿"), "expected a UTF-8 BOM"
    lines = csv.delete_prefix("﻿").split("\n").map(&:chomp)
    assert_equal "Hospital ID,Name,Notes,Ejection Fraction,Outcome", lines[0]
    assert_equal "#{entry.patient.hospital_id},#{entry.patient.name},Doing well,,", lines[1]
  end

  test "to_csv neutralises spreadsheet formulas in names, values and labels" do
    field = case_database_fields(:notes)
    field.update!(label: "@label")
    patient = Patient.create!(hospital_id: "H777", name: "=HYPERLINK(\"http://x\")", date_of_birth: "1980-01-01")
    entry = @case_database.entries.create!(patient: patient)
    entry.assign_field_values(field.id.to_s => "+1+1")
    entry.save!

    rows = CSV.parse(@case_database.to_csv.delete_prefix(CaseDatabase::UTF8_BOM))
    assert_includes rows.first, "'@label"
    row = rows.find { |r| r.first == "H777" }
    assert_equal "'=HYPERLINK(\"http://x\")", row[1]
    assert_includes row, "'+1+1"
  end
end
