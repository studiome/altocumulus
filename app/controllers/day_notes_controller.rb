# Inline editing of a day's note on the operations calendar: the band above a
# day opens a form in place (a turbo-frame) that creates, updates or clears the
# day's Holiday row, and a save re-renders just that day's tbody. Administrators
# only, like the holiday master it edits through (Holiday's own validations
# apply, errors show in the form).
#
# The calendar's own params (start/days/view/mine/team_id/alt) ride along in
# every request so the re-rendered day looks exactly like the one it replaces.
class DayNotesController < ApplicationController
  VIEWS = OperationsCalendarController::VIEWS

  before_action :require_admin
  before_action :set_date
  before_action :set_holiday
  helper_method :context_params, :frame_id

  def show
  end

  def edit
  end

  def update
    @holiday.assign_attributes(holiday_params)

    if @holiday.save
      render_day
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @holiday.destroy if @holiday.persisted?
    @holiday = nil
    render_day
  end

  private

    def set_date
      @date = Date.iso8601(params[:date].to_s)
    rescue Date::Error
      head :not_found
    end

    def set_holiday
      @holiday = Holiday.find_or_initialize_by(date: @date)
      @existing = @holiday.persisted?
      # A new note is a note, not a closure, until the closed-day box is ticked.
      @holiday.holiday = false unless @existing
    end

    def holiday_params
      params.expect(holiday: [ :holiday, :name, :note, :slot_count, :slot_duration_minutes ])
    end

    def frame_id
      "day-note-#{@date.iso8601}"
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
