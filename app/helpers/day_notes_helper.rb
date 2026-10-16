# Glue between the operations calendar's day tbodies and the inline day-note
# editor (DayNotesController): the frame the editor lives in and the params
# that let the editor re-render its day as the calendar would have.
module DayNotesHelper
  # The params that rebuild the surrounding calendar: its range (surgery links
  # carry it back), tab, filters and the day's zebra shade.
  def day_note_context(calendar, view:, alternate: false)
    { start: calendar.return_start.iso8601, days: calendar.return_days, view: view, alt: ("1" if alternate) }
      .compact.merge(calendar.filter.to_params)
  end

  # The day's note frame. Kept truly empty (no whitespace) when the day has
  # nothing to show so CSS can hide its row (.ledger-note-row).
  def day_note_frame(date, holiday, context)
    content = render("operations_calendar/note_content", date: date, holiday: holiday, context: context).to_s.strip
    turbo_frame_tag("day-note-#{date.iso8601}") { raw(content) }
  end
end
