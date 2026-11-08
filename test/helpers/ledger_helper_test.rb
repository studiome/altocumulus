require "test_helper"

class LedgerHelperTest < ActionView::TestCase
  include LedgerHelper

  test "a column header carries the column's narrowest width in pixels" do
    column = LedgerColumn.find(:surgery, :team)

    assert_equal "--ledger-col-min: #{(column.min_width * LedgerHelper::MIN_WIDTH_PX_PER_POINT).round}px",
                 ledger_header_attributes(column)[:style]
  end

  test "a column with a screen width pins both its minimum and preferred width to it" do
    style = ledger_header_attributes(LedgerColumn.find(:surgery, :diagnosis_procedure))[:style]

    assert_equal "--ledger-col-min: 200px; --ledger-col-width: 200px", style
  end

  test "wider columns get a larger minimum than narrow ones" do
    diagnosis = ledger_header_attributes(LedgerColumn.find(:surgery, :operator_assistant))[:style][/\d+px/].to_i
    age_sex = ledger_header_attributes(LedgerColumn.find(:surgery, :age_sex))[:style][/\d+px/].to_i

    assert_operator diagnosis, :>, age_sex
  end

  test "badges use the wrapping badge class" do
    cell = LedgerColumn::Cell.new(upper: [ LedgerColumn::Segment.new("Team", :team, nil, "blue"), LedgerColumn::Segment.new("Elective", :scheduling) ])

    assert_select_in ledger_cell(cell), "span.badge.ledger-badge", 2
  end

  test "a patient name link is bold-styled without the underlined inline link class" do
    cell = LedgerColumn::Cell.new(upper: [ LedgerColumn::Segment.new("John Doe", :patient_name, "/x") ])
    html = Nokogiri::HTML.fragment(ledger_cell(cell))

    assert_select html, "a.ledger-primary.app-patient-name-link[href='/x']", 1
    assert_select html, "a.app-inline-link", 0
  end

  test "a patient name without a link still gets the name style" do
    cell = LedgerColumn::Cell.new(upper: [ LedgerColumn::Segment.new("John Doe", :patient_name) ])

    assert_select_in ledger_cell(cell), "span.ledger-primary.app-patient-name-link", 1
  end

  test "the patient column builds its name as a patient_name segment" do
    surgery = surgeries(:three)
    cell = LedgerColumn.find(:surgery, :patient).cell(surgery, LedgerColumn::Context.new(href: ->(_) { "/x" }))

    assert_equal [ :patient_name ], (cell.upper + cell.lower).map(&:kind) & [ :patient_name ]
    assert_equal "John Doe", cell.plain_text.lines.last.strip
  end

  private

    def assert_select_in(html, selector, count)
      assert_select Nokogiri::HTML.fragment(html), selector, count
    end
end
