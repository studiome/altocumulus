# Inline editing of a day's note on the operations calendar: the band above a
# day opens a form in place (a turbo-frame) that creates, updates or clears the
# day's Holiday row, and a save re-renders just that day's tbody. Administrators
# only, like the holiday master it edits through (Holiday's own validations
# apply, errors show in the form).
#
# The calendar's own params ride along in every request (see
# CalendarDayRendering).
class DayNotesController < ApplicationController
  include CalendarDayRendering

  before_action :require_admin
  before_action :set_date
  before_action :set_holiday
  helper_method :frame_id

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
end
