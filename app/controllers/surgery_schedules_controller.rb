class SurgerySchedulesController < ApplicationController
  def index
    @week_start = week_start
    @dates = (@week_start..(@week_start + 6.days)).to_a
    @slot_usages = ElectiveSlotUsage.for_dates(@dates)
    @previous_week = @week_start - 7.days
    @next_week = @week_start + 7.days
  end

  # A printable landscape PDF of the seven days starting on `start_date`. Unlike
  # the board above (which always snaps to a Monday), the start date is used
  # as given, so a ward can print e.g. Wednesday through the following Tuesday.
  def pdf
    start_date = pdf_start_date
    send_data WeeklySurgerySchedulePdf.new(start_date).render,
              filename: "surgery_schedule_#{start_date.iso8601}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

  private

    # Date.iso8601 (not Date.parse) so only a plain YYYY-MM-DD string is
    # accepted; anything else, including a crafted Array param, falls back to
    # today.
    def pdf_start_date
      Date.iso8601(params[:start_date].to_s)
    rescue ArgumentError
      Date.current
    end

    def week_start
      base = params[:week_of].present? ? Date.parse(params[:week_of].to_s) : Date.current
      base.beginning_of_week
    rescue ArgumentError
      Date.current.beginning_of_week
    end
end
