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
  PAGE_WIDTH = 841.89 # A4 landscape
  # Black, white and grays only: the sheet is meant for a monochrome printer, so
  # nothing may depend on hue. Emergency cases are told apart by the "Emergency"
  # label in the type column plus a gray fill, cases outside the regular slot
  # time (the category column says which) by a lighter one (badges print as
  # text). Four distinct grays: column heads, day headings, emergency, off-slot.
  HEAD_COLOR = "BFBFBF".freeze
  DAY_COLOR = "D4D4D4".freeze
  EMERGENCY_COLOR = "E2E2E2".freeze
  OFF_SLOT_COLOR = "F2F2F2".freeze
  LINE_COLOR = "666666".freeze
  TEXT_COLOR = "000000".freeze
  MUTED_TEXT_COLOR = "555555".freeze

  attr_reader :start_date

  def initialize(start_date)
    @start_date = start_date.to_date
  end

  def end_date
    start_date + (DAYS - 1).days
  end

  # The page width the table may use (points).
  def content_width
    PAGE_WIDTH - (2 * MARGIN)
  end

  # Column widths and font size for the configured columns on this page.
  def column_fit
    @column_fit ||= LedgerColumnFitting.fit(columns, content_width, font_size: SiteConfig.current.weekly_pdf_font_size)
  end

  def render
    pdf = Prawn::Document.new(page_size: "A4", page_layout: :landscape, margin: MARGIN,
                              info: { Title: title })
    pdf.font_families.update("IPAex" => { normal: FONT_PATH.to_s })
    pdf.font "IPAex"
    pdf.fill_color TEXT_COLOR

    draw_title(pdf)
    draw_table(pdf)
    draw_page_numbers(pdf)
    pdf.render
  end

  private

    def title
      SiteConfig.current.weekly_pdf_title || I18n.t("surgery_schedules.pdf.title")
    end

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
      pdf.text title, size: 15
      pdf.text I18n.t("surgery_schedules.pdf.period", from: I18n.l(start_date, format: :default), to: I18n.l(end_date, format: :default)),
               size: 10
      pdf.move_down 3
      draw_legend(pdf)
      pdf.move_down 6
    end

    # One line under the title saying what the two fills mean, each next to a
    # swatch of its own gray.
    def draw_legend(pdf)
      size = 8
      swatch = size
      y = pdf.cursor
      x = 0
      [ [ EMERGENCY_COLOR, "surgery_schedules.pdf.legend_emergency" ], [ OFF_SLOT_COLOR, "surgery_schedules.pdf.legend_off_slot" ] ].each do |color, key|
        label = I18n.t(key)
        pdf.fill_color color
        pdf.stroke_color LINE_COLOR
        pdf.line_width 0.5
        pdf.fill_and_stroke_rectangle [ x, y ], swatch * 1.6, swatch
        pdf.fill_color TEXT_COLOR
        pdf.text_box label, at: [ x + (swatch * 1.6) + 4, y ], size: size, height: swatch + 2, overflow: :truncate
        x += (swatch * 1.6) + 4 + pdf.width_of(label, size: size) + 16
      end
      pdf.move_down swatch + 2
    end

    def draw_table(pdf)
      rows = [ heading_row ]
      dates.each { |date| rows.concat(day_rows(date)) }

      pdf.table(rows, header: true, column_widths: column_fit.widths,
                      cell_style: { size: column_fit.font_size, padding: [ 3, 4 ], border_width: 0.5, border_color: LINE_COLOR }) do |table|
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

    # Date (weekday), the closed-day name and/or day note (notes squished to
    # one line), the slot count when the day overrides it, the slot usage in
    # minutes (used/capacity, only when the day has slots), the special slot
    # lanes (used/lanes per resource) and the case count.
    def day_heading(date, surgeries)
      parts = [ "#{I18n.l(date, format: :default)} (#{I18n.l(date, format: :weekday)})" ]
      holiday = holidays[date]
      parts.concat([ holiday&.name, holiday&.note&.squish ].select(&:present?))
      parts << I18n.t("surgery_schedules.pdf.slot_count", slots: holiday.slot_count_display) if holiday&.slot_override?
      usage = slot_usage(date, surgeries)
      parts << I18n.t("surgery_schedules.pdf.slot_usage", used: usage.used_minutes, capacity: usage.capacity_minutes) if usage.configured?
      parts.concat(usage.special_slots.map(&:summary))
      parts << I18n.t("surgery_schedules.pdf.day_count", count: surgeries.size)
      parts.join("   ")
    end

    # The day's slot usage, built from the surgeries already loaded for the
    # page (and the one-query rule/holiday lookups), not queried again.
    def slot_usage(date, surgeries)
      ElectiveSlotUsage.new(date: date, rule: slot_rules[date.wday], holiday: holidays[date],
                            elective_surgeries: surgeries.select(&:elective?), emergency_surgeries: surgeries.select(&:emergency?),
                            special_rules: special_rules, special_overrides: special_overrides[date] || [])
    end

    def slot_rules
      @slot_rules ||= ElectiveSlotRule.by_day_of_week
    end

    def special_rules
      @special_rules ||= ElectiveSlotUsage.load_special_rules
    end

    def special_overrides
      @special_overrides ||= ElectiveSlotUsage.load_special_overrides(dates).group_by(&:date)
    end

    def surgery_row(surgery)
      cells = columns.map { |column| column.cell(surgery, context).plain_text }
      fill = row_fill(surgery)
      fill ? cells.map { |content| { content: content, background_color: fill } } : cells
    end

    # Emergency shading wins over the lighter off-slot shading.
    def row_fill(surgery)
      return EMERGENCY_COLOR if surgery.emergency?

      OFF_SLOT_COLOR unless surgery.regular_slot?
    end

    def draw_page_numbers(pdf)
      # number_pages stamps every page, so it carries the print time as well.
      pdf.number_pages I18n.t("surgery_schedules.pdf.printed_at", time: I18n.l(Time.current, format: :short)),
                       at: [ 0, -14 ], width: 300, size: 8
      pdf.number_pages "<page> / <total>", at: [ pdf.bounds.right - 100, -14 ], width: 100, align: :right, size: 8
    end
end
