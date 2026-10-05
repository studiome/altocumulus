# Lets the surgery screens find their way back to the operations calendar.
#
# The calendar links to a surgery with `from=calendar` plus its own `start`
# and `days`. Those params come from the query string, so nothing is trusted
# beyond what parses: `from` must be exactly "calendar", `start` an ISO date,
# `days` an integer within the calendar's limits (a bad one is simply
# dropped). Back links are only ever built from our own route helpers, never
# from a URL taken out of the request, so there is no open redirect.
module CalendarReturn
  extend ActiveSupport::Concern

  # Days either side of an out-of-range surgery date shown after saving it.
  LOOKBACK_DAYS = 7

  included do
    helper_method :from_calendar?, :calendar_return_params, :calendar_back_path
  end

  private

    def from_calendar?
      params[:from] == "calendar"
    end

    # The params that carry the calendar origin from one surgery screen to the
    # next; empty unless the request came from the calendar.
    def calendar_return_params
      return {} unless from_calendar?

      { from: "calendar", start: calendar_return_start&.iso8601, days: calendar_return_days }.compact
    end

    # Where the "back" arrow goes: the calendar (at the surgery's day, when
    # it has one) if we came from there, otherwise the surgery list.
    def calendar_back_path(date = nil)
      return surgeries_path unless from_calendar?

      operations_calendar_path(start: calendar_return_start&.iso8601, days: calendar_return_days, anchor: (calendar_day_anchor(date) if date))
    end

    # After saving a dated surgery: the default calendar when the date is on
    # it, otherwise one starting a week before the date, with that day
    # anchored and highlighted.
    def calendar_path_for_saved(date)
      start = OperationsCalendar.default_range.cover?(date) ? nil : (date - LOOKBACK_DAYS).iso8601
      operations_calendar_path(start: start, highlight: date.iso8601, anchor: calendar_day_anchor(date))
    end

    def calendar_day_anchor(date)
      "day-#{date.iso8601}"
    end

    def calendar_return_start
      Date.iso8601(params[:start]) if params[:start].is_a?(String)
    rescue Date::Error
      nil
    end

    def calendar_return_days
      days = Integer(params[:days], exception: false) if params[:days].is_a?(String)
      days if days&.between?(1, OperationsCalendar::MAX_DAYS)
    end
end
