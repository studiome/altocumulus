class DashboardController < ApplicationController
  def index
    @statistics = LedgerStatistics.new(year: params[:year])
    @selected_year = params[:year].presence&.to_i
    @available_years = @statistics.available_years
  end
end
