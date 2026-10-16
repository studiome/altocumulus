# HTML rendering of LedgerColumn cells for the ledger tables (daisyUI /
# app-ledger styles). The PDF flattens the same cells with Cell#plain_text.
module LedgerHelper
  TEXT_CLASSES = {
    primary: "ledger-primary",
    secondary: "ledger-secondary",
    mono: "ledger-primary font-mono",
    secondary_mono: "ledger-secondary font-mono"
  }.freeze

  # daisyUI badges are one line of fixed height; `ledger-badge` (see the CSS)
  # lets them grow and wrap inside a narrow cell instead of overflowing it.
  BADGE_CLASSES = {
    scheduling: "badge badge-sm badge-ghost ledger-badge",
    emergency: "badge badge-sm badge-error ledger-badge",
    off_slot: "badge badge-xs badge-accent ledger-badge",
    partner_department: "badge badge-xs badge-info ledger-badge",
    location: "badge badge-xs badge-outline ledger-badge",
    transfer: "badge badge-xs badge-secondary ledger-badge",
    device: "badge badge-xs badge-neutral ledger-badge",
    team: "badge badge-sm ledger-badge",
    missing: "badge badge-sm badge-warning badge-outline ledger-badge"
  }.freeze

  # LedgerColumn#min_width is in PDF points at the PDF's base font; the HTML
  # table's text is bigger, so scale it to screen pixels.
  MIN_WIDTH_PX_PER_POINT = 1.4

  # The two header tiers: the upper label with the lower one beneath it.
  def ledger_header(column)
    safe_join([ column.header_upper, column.header_lower ].compact.map { |label| tag.span(label, class: "block") })
  end

  # Header cell attributes: the column's own narrowest width (a CSS variable the
  # stylesheet turns into min-width, and drops again for print), so the table
  # scrolls sideways before a column is squeezed.
  def ledger_header_attributes(column)
    { style: "--ledger-col-min: #{(column.min_width * MIN_WIDTH_PX_PER_POINT).round}px" }
  end

  # A cell's upper and lower parts. Badges are stacked in a column; text
  # segments keep the ledger-primary / ledger-secondary stacking.
  def ledger_cell(cell)
    segments = (cell.upper + cell.lower).map { |segment| ledger_segment(segment) }
    return safe_join(segments) unless cell.badges?

    tag.div(safe_join(segments), class: "flex flex-col gap-1 items-start")
  end

  private

    def ledger_segment(segment)
      if segment.badge?
        tag.span(segment.text, class: ledger_badge_class(segment))
      elsif segment.href.present?
        link_to segment.text, segment.href, class: "#{TEXT_CLASSES.fetch(segment.kind)} app-inline-link"
      else
        tag.span(segment.text, class: TEXT_CLASSES.fetch(segment.kind))
      end
    end

    def ledger_badge_class(segment)
      return "badge badge-sm ledger-badge #{Team::BADGE_CLASSES.fetch(segment.color, Team::BADGE_CLASSES['gray'])}" if segment.kind == :team

      BADGE_CLASSES.fetch(segment.kind)
    end
end
