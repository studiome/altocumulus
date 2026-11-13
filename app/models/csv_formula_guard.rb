# One implementation of the CSV-injection defence shared by every CSV the app
# writes: a text cell that starts with = + - @ (or a tab / CR) is prefixed
# with a single quote so a spreadsheet cannot run it as a formula. Numbers,
# dates and nil are untouched.
module CsvFormulaGuard
  FORMULA_PREFIXES = [ "=", "+", "-", "@", "\t", "\r" ].freeze

  def self.neutralize(value)
    return value unless value.is_a?(String) && value.start_with?(*FORMULA_PREFIXES)

    "'#{value}"
  end

  def self.neutralize_row(row)
    row.map { |value| neutralize(value) }
  end
end
