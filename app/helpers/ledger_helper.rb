# HTML rendering of LedgerColumn cells for the ledger tables (daisyUI /
# app-ledger styles). The PDF flattens the same cells with Cell#plain_text.
module LedgerHelper
  TEXT_CLASSES = {
    primary: "ledger-primary",
    secondary: "ledger-secondary",
    mono: "ledger-primary font-mono",
    secondary_mono: "ledger-secondary font-mono"
  }.freeze

  BADGE_CLASSES = {
    scheduling: "badge badge-sm badge-ghost",
    emergency: "badge badge-sm badge-error",
    off_slot: "badge badge-xs badge-accent whitespace-nowrap",
    partner_department: "badge badge-xs badge-info whitespace-nowrap",
    location: "badge badge-xs badge-outline whitespace-nowrap",
    transfer: "badge badge-xs badge-secondary whitespace-nowrap",
    device: "badge badge-xs badge-neutral whitespace-nowrap",
    team: "badge badge-sm",
    missing: "badge badge-sm badge-warning badge-outline"
  }.freeze

  # The two header tiers: the upper label with the lower one beneath it.
  def ledger_header(column)
    safe_join([ column.header_upper, column.header_lower ].compact.map { |label| tag.span(label, class: "block") })
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
      return "badge badge-sm #{Team::BADGE_CLASSES.fetch(segment.color, Team::BADGE_CLASSES['gray'])}" if segment.kind == :team

      BADGE_CLASSES.fetch(segment.kind)
    end
end
