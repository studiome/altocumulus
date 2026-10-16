require "csv"

# Renders an ExportDefinition's rows as an Excel-friendly CSV: UTF-8 with a
# byte order mark (so Excel does not guess Shift_JIS), CRLF line endings, one
# header row, every field quoted. Values are exact -- Excel itself drops a
# patient ID's leading zeros when it opens the file by double click (import
# the column as text to keep them).
#
# A text cell that starts with = + - @ (or a tab / CR) is prefixed with a
# single quote so a spreadsheet cannot run it as a formula (CSV injection);
# numbers and dates are untouched.
class CsvExport
  BOM = "﻿".freeze
  ROW_SEPARATOR = "\r\n".freeze
  FORMULA_PREFIXES = [ "=", "+", "-", "@", "\t", "\r" ].freeze

  def initialize(definition, records)
    @definition = definition
    @records = records
    @fields = definition.export_fields
  end

  def to_csv
    csv = CSV.generate(row_sep: ROW_SEPARATOR, force_quotes: true) do |out|
      out << @fields.map { |field| neutralize(field.header) }
      @records.each { |record| out << @fields.map { |field| neutralize(field.value(record)) } }
    end
    BOM + csv
  end

  # <export key>_<from>_<to>.csv, ASCII only; an open end reads "all".
  def self.filename(definition, from:, to:)
    parts = [ definition.key, from&.iso8601 || "all", to&.iso8601 || "all" ]
    parts = [ definition.key, "all" ] if from.nil? && to.nil?
    "#{parts.compact.map { |part| part.to_s.gsub(/[^A-Za-z0-9_-]/, "") }.join('_')}.csv"
  end

  private

    def neutralize(value)
      return value unless value.is_a?(String) && value.start_with?(*FORMULA_PREFIXES)

      "'#{value}"
    end
end
