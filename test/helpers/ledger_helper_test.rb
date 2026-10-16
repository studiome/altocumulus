require "test_helper"

class LedgerHelperTest < ActionView::TestCase
  include LedgerHelper

  test "a column header carries the column's narrowest width in pixels" do
    column = LedgerColumn.find(:surgery, :team)

    assert_equal "--ledger-col-min: #{(column.min_width * LedgerHelper::MIN_WIDTH_PX_PER_POINT).round}px",
                 ledger_header_attributes(column)[:style]
  end

  test "wider columns get a larger minimum than narrow ones" do
    diagnosis = ledger_header_attributes(LedgerColumn.find(:surgery, :diagnosis_procedure))[:style][/\d+px/].to_i
    age_sex = ledger_header_attributes(LedgerColumn.find(:surgery, :age_sex))[:style][/\d+px/].to_i

    assert_operator diagnosis, :>, age_sex
  end

  test "badges use the wrapping badge class" do
    cell = LedgerColumn::Cell.new(upper: [ LedgerColumn::Segment.new("Team", :team, nil, "blue"), LedgerColumn::Segment.new("Elective", :scheduling) ])

    assert_select_in ledger_cell(cell), "span.badge.ledger-badge", 2
  end

  private

    def assert_select_in(html, selector, count)
      assert_select Nokogiri::HTML.fragment(html), selector, count
    end
end
