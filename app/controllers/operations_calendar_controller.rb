# The day-by-day operations view (elective slot usage, admission load,
# holidays/comments, and cross-cutting summaries). All the actual work is in
# OperationsCalendar; this controller only turns request params into a
# calendar (or a friendly redirect when they don't make sense).
class OperationsCalendarController < ApplicationController
  def index
    @calendar = OperationsCalendar.build(start: params[:start], days: params[:days])
  rescue OperationsCalendar::InvalidRangeError
    redirect_to operations_calendar_path, alert: "The requested date range was invalid. Showing the default range instead."
  end
end
