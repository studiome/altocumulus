# The day-by-day operations view (elective slot usage, admission load,
# holidays/comments, and cross-cutting summaries). All the actual work is in
# OperationsCalendar; this controller only turns request params into a
# calendar (or a friendly redirect when they don't make sense).
class OperationsCalendarController < ApplicationController
  def index
    @calendar = OperationsCalendar.build(start: params[:start], days: params[:days])
    @highlight = parse_highlight(params[:highlight])
  rescue OperationsCalendar::InvalidRangeError
    redirect_to operations_calendar_path, alert: t(".alert")
  end

  private

    # The day to briefly emphasize after a surgery was saved; anything that
    # is not a plain date string is ignored.
    def parse_highlight(value)
      Date.iso8601(value) if value.is_a?(String)
    rescue Date::Error
      nil
    end
end
