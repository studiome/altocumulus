require "test_helper"

class CsvExportTest < ActiveSupport::TestCase
  def definition(fields, subject: :surgery)
    ExportDefinition.new(key: :sample_list, subject: subject, fields: fields, label: nil)
  end

  def csv(fields, records, **options)
    CsvExport.new(definition(fields, **options), records).to_csv
  end

  test "starts with a BOM, uses CRLF and has one header row" do
    out = csv(%i[surgery_date hospital_id], [ surgeries(:three), surgeries(:four) ])
    assert out.start_with?("﻿")
    lines = out.delete_prefix("﻿").split("\r\n")
    assert_equal 3, lines.size
    assert_equal '"Surgery Date","Patient ID"', lines.first
    assert_equal '"2026-03-03","H001"', lines[1]
    assert_equal '"2026-03-03","H002"', lines[2]
    assert_not_includes out.delete("\r"), "\r"
  end

  test "headers follow the locale" do
    out = I18n.with_locale(:ja) { csv(%i[surgery_date hospital_id], []) }
    assert_equal "﻿\"手術日\",\"患者ID\"\r\n", out
  end

  test "ids keep leading zeros and are quoted" do
    patient = Patient.new(hospital_id: "00012345", name: "A")
    surgery = Surgery.new(patient: patient)
    assert_includes csv(%i[hospital_id], [ surgery ]), "\"00012345\""
  end

  test "commas, quotes and line breaks are escaped" do
    surgery = surgeries(:one)
    surgery.operator_name = %(Dr. "A", B\nC)
    assert_includes csv(%i[operator], [ surgery ]), %("Dr. ""A"", B\nC")
  end

  test "blank values are empty cells and no records gives only the header" do
    assert_equal "﻿\"Start Time\"\r\n\"\"\r\n", csv(%i[start_time], [ surgeries(:one) ])
    assert_equal "﻿\"Start Time\"\r\n", csv(%i[start_time], [])
  end

  test "text that a spreadsheet would run as a formula is defused" do
    surgery = surgeries(:one)
    [ "=SUM(A1)", "+1", "-1", "@x" ].each do |text|
      surgery.operator_name = text
      assert_includes csv(%i[operator], [ surgery ]), "\"'#{text}\""
    end
    surgery.operator_name = "Dr =x"
    assert_includes csv(%i[operator], [ surgery ]), "\"Dr =x\""
    assert_includes csv(%i[surgery_date], [ surgeries(:one) ]), "\"2026-03-01\""
  end

  test "the file name is ascii: key, start and end" do
    assert_equal "sample_list_2026-10-19_2026-12-07.csv", CsvExport.filename(definition([ :surgery_date ]), from: Date.new(2026, 10, 19), to: Date.new(2026, 12, 7))
    assert_equal "sample_list_all.csv", CsvExport.filename(definition([ :surgery_date ]), from: nil, to: nil)
    assert_equal "sample_list_2026-10-19_all.csv", CsvExport.filename(definition([ :surgery_date ]), from: Date.new(2026, 10, 19), to: nil)
  end
end
