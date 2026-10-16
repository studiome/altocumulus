require "test_helper"

class LedgerColumnFittingTest < ActiveSupport::TestCase
  Col = Struct.new(:width, :min_width, :flex) do
    def flex? = flex
  end

  def fit(columns, total, **options)
    LedgerColumnFitting.fit(columns, total, **options)
  end

  # fixed 40/30, flex 100/60, fixed 60/40, flex 100/60 => preferred 300, min 190
  def sample
    [ Col.new(40, 30, false), Col.new(100, 60, true), Col.new(60, 40, false), Col.new(100, 60, true) ]
  end

  test "spare width goes to the flexible columns in proportion to their preferred widths" do
    result = fit(sample, 400)

    assert_equal 8, result.font_size
    assert_equal [ 40, 60 ], [ result.widths[0], result.widths[2] ]
    assert_in_delta result.widths[1], result.widths[3], 0.01
    assert_in_delta 400, result.widths.sum, 0.05
    assert_operator result.widths.sum, :<=, 400
    assert_operator result.widths[1], :>, 100
  end

  test "an uneven split follows the preferred widths" do
    columns = [ Col.new(40, 30, false), Col.new(100, 60, true), Col.new(200, 60, true) ]
    result = fit(columns, 540) # preferred 340, 200 spare

    assert_in_delta 40, result.widths[0], 0.05
    assert_in_delta 100 + 200 * (100 / 300.0), result.widths[1], 0.05
    assert_in_delta 200 + 200 * (200 / 300.0), result.widths[2], 0.05
  end

  test "without flexible columns the spare width is shared by all columns in proportion" do
    result = fit([ Col.new(100, 50, false), Col.new(300, 50, false) ], 800)

    assert_in_delta 200, result.widths[0], 0.05
    assert_in_delta 600, result.widths[1], 0.05
  end

  test "exactly the preferred widths when they fit exactly" do
    result = fit(sample, 300)
    assert_equal [ 40, 100, 60, 100 ], result.widths.map(&:round)
  end

  test "shrinks proportionally between preferred and minimum widths" do
    result = fit(sample, 245) # slack halfway: min 190 .. preferred 300

    assert_equal 8, result.font_size
    assert_in_delta 245, result.widths.sum, 0.05
    sample.zip(result.widths).each do |column, width|
      assert_in_delta column.min_width + (column.width - column.min_width) * 0.5, width, 0.05
    end
  end

  test "never goes below the minimum widths while they fit" do
    result = fit(sample, 190)
    sample.zip(result.widths).each { |column, width| assert_operator width, :>=, column.min_width - 0.01 }
    assert_equal 8, result.font_size
  end

  test "reduces the font step by step before shrinking below the minimums" do
    # minimums total 190; at 7.5pt they need 190 * 7.5 / 8 = 178.1
    result = fit(sample, 180)
    assert_equal 7.5, result.font_size
    assert_operator result.widths.sum, :<=, 180
    sample.zip(result.widths).each { |column, width| assert_operator width, :>=, column.min_width * 7.5 / 8 - 0.01 }

    assert_equal 7, fit(sample, 170).font_size   # needs 166.25
    assert_equal 6.5, fit(sample, 160).font_size # needs 154.4
  end

  test "when even the smallest font does not fit the minimums shrink proportionally" do
    result = fit(sample, 100)

    assert_equal 6.5, result.font_size
    assert_operator result.widths.sum, :<=, 100
    assert_in_delta 100, result.widths.sum, 0.1
    assert_in_delta result.widths[1] / result.widths[0], 2.0, 0.05 # 60:30 minimums keep their ratio
  end

  test "starts from the configured font size and steps down by half points, never below 6" do
    assert_equal 10, fit(sample, 400, font_size: 10).font_size
    assert_equal 9.5, fit(sample, 190 * 1.25 - 1, font_size: 10).font_size
    assert_equal 6, fit(sample, 10, font_size: 6).font_size
    assert_equal [ 8, 7.5, 7, 6.5 ], LedgerColumnFitting.font_steps(8)
    assert_equal [ 10, 9.5, 9, 8.5 ], LedgerColumnFitting.font_steps(10)
    assert_equal [ 6 ], LedgerColumnFitting.font_steps(6)
    assert_equal [ 7, 6.5, 6 ], LedgerColumnFitting.font_steps(7)
  end

  test "a larger font scales the widths so the same text still fits" do
    at_ten = fit(sample, 1000, font_size: 10)
    assert_in_delta 1000, at_ten.widths.sum, 0.05

    # preferred widths grow with the font: 300 * 10 / 8 = 375, so 375 fits exactly
    exact = fit(sample, 375, font_size: 10)
    assert_equal 10, exact.font_size
    assert_in_delta 125, exact.widths[1], 0.05
  end

  test "every registered column has a positive minimum not above its preferred width" do
    LedgerColumn.registry.each_value do |column|
      assert_operator column.min_width, :>, 0, "#{column.subject}/#{column.key}"
      assert_operator column.min_width, :<=, column.width, "#{column.subject}/#{column.key}"
    end
  end

  test "the registry flags the wide text columns as flexible and states the agreed minimums" do
    flex = LedgerColumn.registry.values.select(&:flex?).map(&:key).uniq.sort
    assert_equal %i[category diagnosis_procedure diagnosis_procedure_name referral_adl], flex

    assert_equal 80, LedgerColumn.find(:surgery, :patient).min_width
    assert_equal 150, LedgerColumn.find(:surgery, :diagnosis_procedure).min_width
    assert_equal 90, LedgerColumn.find(:surgery, :category).min_width
    assert_equal 36, LedgerColumn.find(:surgery, :age_sex).min_width
    assert_equal 44, LedgerColumn.find(:surgery, :duration_anesthesia).min_width
  end

  test "the default weekly PDF columns fit the page at the base font" do
    result = fit(LedgerColumn.for_ledger(:weekly_pdf), 785.89)
    assert_equal 8, result.font_size
    assert_in_delta 785.89, result.widths.sum, 0.1
  end

  test "all surgery columns fit the page by shrinking the font, not the minimums" do
    columns = LedgerColumn.keys(:surgery).map { |key| LedgerColumn.find(:surgery, key) }
    result = fit(columns, 785.89)

    assert_operator result.font_size, :<=, 8
    assert_operator result.widths.sum, :<=, 785.89
    columns.zip(result.widths).each { |column, width| assert_operator width, :>=, column.min_width * result.font_size / 8 - 0.05 }
  end
end
