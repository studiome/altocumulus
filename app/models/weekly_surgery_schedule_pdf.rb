# Renders seven days of surgeries, starting on an arbitrary date, as a landscape
# A4 PDF for printing. One ledger-style table: a shaded heading row per day
# (date, holiday name, case count) followed by that day's surgeries, with the
# column headings repeated on every page. The columns, and their order, are the
# site's ledger_columns.weekly_pdf (see LedgerColumn); each cell is the
# column's value flattened to plain text.
#
# Text is set in the bundled IPAex Gothic (vendor/fonts, IPA Font License) so
# Japanese renders without depending on fonts installed on the server. The
# font has no bold face, so emphasis comes from shading instead.
class WeeklySurgerySchedulePdf
  FONT_PATH = Rails.root.join("vendor/fonts/ipaexg.ttf")
  DAYS = 7
  MARGIN = 28
  # Black, white and grays only: the sheet is meant for a monochrome printer, so
  # nothing may depend on hue. Emergency cases are told apart by the "Emergency"
  # label in the type column plus a light gray fill (badges print as text).
  HEAD_COLOR = "D0D0D0".freeze
  DAY_COLOR = "E6E6E6".freeze
  LINE_COLOR = "666666".freeze
  TEXT_COLOR = "000000".freeze
  MUTED_TEXT_COLOR = "555555".freeze
  EMERGENCY_COLOR = "F2F2F2".freeze

  attr_reader :start_date

  def initialize(start_date)
    @start_date = start_date.to_date
  end

  # Widths (points) for the columns, fitting `total`. Each column brings a
  # default width; when they add up to less than the page the last column takes
  # the remainder (a hard-coded total would be off by a fraction of a point, and
  # Prawn refuses a table wider than the page), and when they add up to more
  # they are all scaled down in proportion (rounded down, never over).
  def column_widths(columns, total)
    defaults = columns.map(&:width)
    sum = defaults.sum
    return defaults[0...-1] + [ total - defaults[0...-1].sum ] if sum <= total

    factor = total.to_f / sum
    defaults.map { |width| (width * factor).floor(2) }
  end

  def end_date
    start_date + (DAYS - 1).days
  end

  def render
    pdf = Prawn::Document.new(page_size: "A4", page_layout: :landscape, margin: MARGIN,
                              info: { Title: I18n.t("surgery_schedules.pdf.title") })
    pdf.font_families.update("IPAex" => { normal: FONT_PATH.to_s })
    pdf.font "IPAex"
    pdf.fill_color TEXT_COLOR

    draw_title(pdf)
    draw_table(pdf)
    draw_page_numbers(pdf)
    pdf.render
  end

  private

    def dates
      @dates ||= (start_date..end_date).to_a
    end

    def surgeries_by_date
      @surgeries_by_date ||= Surgery.where(surgery_date: dates)
                                    .includes(:patient, :department, :surgery_location, :surgical_device, :hospitalization,
                                              { patient_diagnoses: :diagnosis }, { surgery_procedure_selections: :surgery_procedure },
                                              *LedgerColumn.includes_for(columns))
                                    .group_by(&:surgery_date)
                                    .transform_values { |list| list.sort_by { |surgery| sort_key(surgery) } }
    end

    def columns
      @columns ||= LedgerColumn.for_ledger(:weekly_pdf)
    end

    def context
      @context ||= LedgerColumn::Context.new(referral_lookup: referral_lookup)
    end

    def referral_lookup
      @referral_lookup ||= SurgeryReferralLookup.new(
        patient_ids: surgeries_by_date.values.flatten.map(&:patient_id), dates: dates
      )
    end

    def holidays
      @holidays ||= Holiday.by_date(dates)
    end

    # Elective cases first in slot then time order, emergencies after them.
    def sort_key(surgery)
      [ surgery.emergency? ? 1 : 0, surgery.slot_number || 99, surgery.start_time&.strftime("%H:%M") || "99:99", surgery.id ]
    end

    def draw_title(pdf)
      pdf.text I18n.t("surgery_schedules.pdf.title"), size: 15
      pdf.text I18n.t("surgery_schedules.pdf.period", from: I18n.l(start_date, format: :default), to: I18n.l(end_date, format: :default)),
               size: 10
      pdf.move_down 8
    end

    def draw_table(pdf)
      rows = [ heading_row ]
      dates.each { |date| rows.concat(day_rows(date)) }

      widths = column_widths(columns, pdf.bounds.width)
      pdf.table(rows, header: true, column_widths: widths,
                      cell_style: { size: 8, padding: [ 3, 4 ], border_width: 0.5, border_color: LINE_COLOR }) do |table|
        table.row(0).background_color = HEAD_COLOR
        table.row(0).text_color = TEXT_COLOR
      end
    end

    def heading_row
      columns.map { |column| [ column.header_upper, column.header_lower ].compact.join("\n") }
    end

    def day_rows(date)
      surgeries = surgeries_by_date[date] || []
      rows = [ [ { content: day_heading(date, surgeries), colspan: columns.size, background_color: DAY_COLOR } ] ]

      if surgeries.empty?
        rows << [ { content: I18n.t("surgery_schedules.pdf.no_surgeries"), colspan: columns.size, text_color: MUTED_TEXT_COLOR } ]
      else
        surgeries.each { |surgery| rows << surgery_row(surgery) }
      end
      rows
    end

    def day_heading(date, surgeries)
      parts = [ "#{I18n.l(date, format: :default)} (#{I18n.l(date, format: :weekday)})" ]
      holiday = holidays[date]
      # A Holiday row is either a closed day (name) or a plain day comment
      # (note); show whichever of the two it has, notes flattened to one line.
      parts.concat([ holiday&.name, holiday&.note&.squish ].select(&:present?))
      parts << slot_override_label(holiday) if holiday&.slot_override?
      parts << I18n.t("surgery_schedules.pdf.day_count", count: surgeries.size)
      parts.join("   ")
    end

    def slot_override_label(holiday)
      I18n.t("surgery_schedules.pdf.slot_override", slots: holiday.slot_count_display)
    end

    def surgery_row(surgery)
      cells = columns.map { |column| column.cell(surgery, context).plain_text }
      surgery.emergency? ? cells.map { |content| { content: content, background_color: EMERGENCY_COLOR } } : cells
    end

    def draw_page_numbers(pdf)
      # number_pages stamps every page, so it carries the print time as well.
      pdf.number_pages I18n.t("surgery_schedules.pdf.printed_at", time: I18n.l(Time.current, format: :short)),
                       at: [ 0, -14 ], width: 300, size: 8
      pdf.number_pages "<page> / <total>", at: [ pdf.bounds.right - 100, -14 ], width: 100, align: :right, size: 8
    end
end
