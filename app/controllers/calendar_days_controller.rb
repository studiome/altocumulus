# One day of the operations calendar as the signed-in viewer would see it, for
# the live calendar to swap in when a LiveUpdate says that day changed. Same
# context params and rendering as the day editors (CalendarDayRendering), but
# open to every signed-in user: it renders nothing a calendar page would not.
class CalendarDaysController < ApplicationController
  include CalendarDayRendering

  before_action :set_date

  def show
    render_day
  end
end
