# Renders seven days of surgeries, starting on an arbitrary date, as a landscape
# A4 PDF for printing. One ledger-style table: a shaded heading row per day
# (date, holiday name, case count) followed by that day's surgeries, with the
# column headings repeated on every page.
#
# Text is set in the bundled IPAex Gothic (vendor/fonts, IPA Font License) so
# Japanese renders without depending on fonts installed on the server. The
# font has no bold face, so emphasis comes from shading instead.
class WeeklySurgerySchedulePdf
  FONT_PATH = Rails.root.join("vendor/fonts/ipaexg.ttf")
  DAYS = 7
  MARGIN = 28
  # Fixed widths for every column but the last, which takes whatever is left of
  # the printable width (A4 is 841.89pt wide, so a hard-coded total would be off
  # by a fraction of a point and Prawn refuses a table wider than the page).
  FIXED_COLUMN_WIDTHS = [ 44, 34, 108, 130, 168, 80, 46, 66 ].freeze
  COLUMN_KEYS = %i[time slot patient diagnosis procedure operator duration anesthesia category].freeze

  HEAD_COLOR = "DFE3F2".freeze
  DAY_COLOR = "E8E8F0".freeze
  LINE_COLOR = "8A8AC0".freeze
  TEXT_COLOR = "111133".freeze
  EMERGENCY_COLOR = "FBE3E3".freeze

  attr_reader :start_date

  def initialize(start_date)
    @start_date = start_date.to_date
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
                                    .includes(:patient, { patient_diagnoses: :diagnosis },
                                              { surgery_procedure_selections: :surgery_procedure })
                                    .group_by(&:surgery_date)
                                    .transform_values { |list| list.sort_by { |surgery| sort_key(surgery) } }
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

      widths = FIXED_COLUMN_WIDTHS + [ pdf.bounds.width - FIXED_COLUMN_WIDTHS.sum ]
      pdf.table(rows, header: true, column_widths: widths,
                      cell_style: { size: 8, padding: [ 3, 4 ], border_width: 0.5, border_color: LINE_COLOR }) do |table|
        table.row(0).background_color = HEAD_COLOR
        table.row(0).text_color = "000080"
      end
    end

    def heading_row
      COLUMN_KEYS.map { |key| I18n.t("surgery_schedules.pdf.columns.#{key}") }
    end

    def day_rows(date)
      surgeries = surgeries_by_date[date] || []
      rows = [ [ { content: day_heading(date, surgeries), colspan: COLUMN_KEYS.size, background_color: DAY_COLOR } ] ]

      if surgeries.empty?
        rows << [ { content: I18n.t("surgery_schedules.pdf.no_surgeries"), colspan: COLUMN_KEYS.size, text_color: "777777" } ]
      else
        surgeries.each { |surgery| rows << surgery_row(surgery) }
      end
      rows
    end

    def day_heading(date, surgeries)
      parts = [ "#{I18n.l(date, format: :default)} (#{I18n.l(date, format: :weekday)})" ]
      parts << holidays[date].name if holidays[date]&.name.present?
      parts << I18n.t("surgery_schedules.pdf.day_count", count: surgeries.size)
      parts.join("   ")
    end

    def surgery_row(surgery)
      cells = [
        surgery.start_time_display,
        surgery.regular_slot? ? surgery.slot_number.to_s.presence || "-" : "-",
        "#{surgery.patient.hospital_id}\n#{surgery.patient.name.presence || I18n.t('surgery_schedules.labels.unknown_patient_name', id: surgery.patient_id)}",
        surgery.diagnosis_names_display,
        surgery.display_procedure_name,
        operator_text(surgery),
        surgery.duration_minutes ? I18n.t("surgery_schedules.slot_surgery.duration_minutes_value", minutes: surgery.duration_minutes) : "-",
        surgery.anesthesia_method.to_s,
        category_text(surgery)
      ]
      surgery.emergency? ? cells.map { |content| { content: content, background_color: EMERGENCY_COLOR } } : cells
    end

    # Operator over assistant, mirroring the stacked cell on the surgery list.
    def operator_text(surgery)
      [ surgery.operator_name.presence || "-", surgery.assistant_name.presence ].compact.join("\n")
    end

    def category_text(surgery)
      lines = [ surgery.scheduling_type_label ]
      unless surgery.regular_slot?
        detail = surgery.target_department.presence || surgery.location.presence
        lines << [ surgery.slot_category_label, detail ].compact.join(": ")
      end
      lines.join("\n")
    end

    def draw_page_numbers(pdf)
      # number_pages stamps every page, so it carries the print time as well.
      pdf.number_pages I18n.t("surgery_schedules.pdf.printed_at", time: I18n.l(Time.current, format: :short)),
                       at: [ 0, -14 ], width: 300, size: 8
      pdf.number_pages "<page> / <total>", at: [ pdf.bounds.right - 100, -14 ], width: 100, align: :right, size: 8
    end
end
