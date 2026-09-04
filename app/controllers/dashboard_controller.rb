class DashboardController < ApplicationController
  def index
    year = params[:year] if params[:year].is_a?(String)
    @statistics = LedgerStatistics.new(year: year)
    @selected_year = year.presence&.to_i
    @available_years = @statistics.available_years
  end
end
