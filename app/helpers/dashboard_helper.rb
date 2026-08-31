module DashboardHelper
  # The "All time" view charts a trailing twelve months, so it can straddle a
  # year boundary; spell the year out in that case to keep the axis unambiguous.
  def monthly_axis_label(month, months)
    return month.strftime("%b") if months.map(&:year).uniq.one?

    month.strftime("%b '%y")
  end
end
