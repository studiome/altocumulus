# The day-by-day operations view with two tabs: surgeries (elective slot usage,
# admission load, holidays/comments) and examination admissions. All the actual
# work is in OperationsCalendar / ExaminationCalendar; this controller only
# turns request params into a calendar (or a friendly redirect when they don't
# make sense).
class OperationsCalendarController < ApplicationController
  VIEWS = %w[surgery examination].freeze

  def index
    @view = VIEWS.include?(params[:view]) ? params[:view] : "surgery"
    @filter = CalendarFilter.from_params(params, user: current_user)
    @calendar = build_calendar
    @highlight = parse_highlight(params[:highlight])
  rescue OperationsCalendar::InvalidRangeError
    redirect_to operations_calendar_path, alert: t(".alert")
  end

  private

    def build_calendar
      options = { start: params[:start], days: params[:days], filter: @filter }
      @view == "examination" ? ExaminationCalendar.build(**options) : OperationsCalendar.build(**options)
    end

    # The day to briefly emphasize after a surgery was saved; anything that
    # is not a plain date string is ignored.
    def parse_highlight(value)
      Date.iso8601(value) if value.is_a?(String)
    rescue Date::Error
      nil
    end
end
