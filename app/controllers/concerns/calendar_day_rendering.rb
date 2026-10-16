# What the inline day editors of the operations calendar (DayNotesController,
# DaySpecialSlotsController) share: the day's ISO date from the URL, the
# calendar params that ride along in every request, and the re-render of just
# that day's tbody after a save so it looks exactly like the one it replaces.
module CalendarDayRendering
  extend ActiveSupport::Concern

  VIEWS = OperationsCalendarController::VIEWS

  included do
    helper_method :context_params
  end

  private

    def set_date
      @date = Date.iso8601(params[:date].to_s)
    rescue Date::Error
      head :not_found
    end

    def view_name
      VIEWS.include?(params[:view]) ? params[:view] : "surgery"
    end

    def context_params
      params.permit(:start, :days, :view, :mine, :team_id, :alt).to_h.symbolize_keys.merge(view: view_name)
    end

    def render_day
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("day-#{@date.iso8601}", partial: day_partial, locals: day_locals)
        end
        format.html { redirect_to operations_calendar_path(context_params.slice(:start, :days, :view, :mine, :team_id)), status: :see_other }
      end
    end

    def day_partial
      view_name == "examination" ? "operations_calendar/examination_day" : "operations_calendar/day"
    end

    def day_locals
      calendar = build_day_calendar
      locals = { date: @date, calendar: calendar, alternate: params[:alt] == "1", highlight: false }
      locals[:usage] = calendar.slot_usages[@date] if view_name == "surgery"
      locals
    end

    # The one day as the calendar would show it, still tied to the range the
    # screen was opened with.
    def build_day_calendar
      start, days = begin
        OperationsCalendar.parse_range(start: params[:start], days: params[:days])
      rescue OperationsCalendar::InvalidRangeError
        [ @date, 1 ]
      end
      options = { start_date: @date, days: 1, filter: CalendarFilter.from_params(params, user: current_user),
                  return_start: start, return_days: days }
      view_name == "examination" ? ExaminationCalendar.new(**options) : OperationsCalendar.new(**options)
    end
end
