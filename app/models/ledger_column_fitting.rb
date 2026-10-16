# Fits a ledger's columns to the width of a PDF page.
#
# Every column has a preferred width and a minimum (LedgerColumn#width /
# #min_width, in points at the base font size of 8pt) and may be flexible. The
# fit, in order of preference:
#   1. the preferred widths fit: the spare width goes to the flexible columns
#      in proportion to their `flex` weights, not their widths, so a column
#      that wraps a lot (the type badges) can be given more than a wide one
#      with room to spare (to all columns, by preferred width, when none is
#      flexible);
#   2. only the minimums fit: every column shrinks towards its minimum by the
#      same share of its slack, so nothing goes below the minimum;
#   3. even the minimums do not fit: the font is reduced step by step
#      (8 -> 7.5 -> 7 -> 6.5; text at a smaller size needs proportionally
#      less width, so the widths scale with the font) and 1-2 are tried again;
#   4. nothing fits at the smallest font: the minimums are shrunk
#      proportionally, the last resort.
# Widths are rounded down (Prawn refuses a table wider than the page), so they
# sum to at most `total`.
module LedgerColumnFitting
  BASE_FONT_SIZE = 8
  FONT_STEP = 0.5
  FONT_STEPS = 4
  MIN_FONT_SIZE = 6

  Result = Data.define(:widths, :font_size)

  class << self
    # The font sizes to try, largest first: the configured one and up to three
    # half-point steps below it, never under MIN_FONT_SIZE.
    def font_steps(font_size)
      steps = (0...FONT_STEPS).map { |index| font_size - (FONT_STEP * index) }.select { |size| size >= MIN_FONT_SIZE }
      steps.empty? ? [ font_size ] : steps
    end

    def fit(columns, total, font_size: BASE_FONT_SIZE)
      steps = font_steps(font_size)

      steps.each do |size|
        ratio = size.to_f / BASE_FONT_SIZE
        mins = columns.map { |column| column.min_width * ratio }
        next if mins.sum > total

        prefs = columns.map { |column| column.width * ratio }
        return Result.new(widths: spread(columns, mins, prefs, total), font_size: size)
      end

      mins = columns.map { |column| column.min_width * steps.last.to_f / BASE_FONT_SIZE }
      factor = total / mins.sum
      Result.new(widths: mins.map { |width| floor(width * factor) }, font_size: steps.last)
    end

    private

      def spread(columns, mins, prefs, total)
        return grow(columns, prefs, total) if prefs.sum <= total

        share = (total - mins.sum) / (prefs.sum - mins.sum)
        mins.zip(prefs).map { |min, pref| floor(min + ((pref - min) * share)) }
      end

      def grow(columns, prefs, total)
        extra = total - prefs.sum
        targets = columns.each_index.select { |index| columns[index].flex? }
        weights = if targets.empty?
          targets = columns.each_index.to_a
          prefs
        else
          columns.map { |column| column.flex.to_f }
        end
        total_weight = targets.sum { |index| weights[index] }

        widths = prefs.dup
        targets.each { |index| widths[index] += extra * weights[index] / total_weight }
        widths = widths.map { |width| floor(width) }

        # Hand the rounding crumbs to the last flexible column.
        last = targets.last
        widths[last] = floor(widths[last] + (total - widths.sum))
        widths
      end

      def floor(width)
        (width * 100).floor / 100.0
      end
  end
end
