class SurgerySchedulesController < ApplicationController
  def index
    @week_start = week_start
    @dates = (@week_start..(@week_start + 6.days)).to_a
    @slot_usages = ElectiveSlotUsage.for_dates(@dates)
    @previous_week = @week_start - 7.days
    @next_week = @week_start + 7.days
  end

  private

    def week_start
      base = params[:week_of].present? ? Date.parse(params[:week_of]) : Date.current
      base.beginning_of_week
    rescue ArgumentError
      Date.current.beginning_of_week
    end
end
