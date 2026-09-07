module DashboardHelper
  # The "All time" view charts a trailing twelve months, so it can straddle a
  # year boundary; spell the year out in that case to keep the axis unambiguous.
  def monthly_axis_label(month, months)
    # I18n.l (not Date#strftime directly) so %b resolves through the current
    # locale's date.abbr_month_names rather than always English.
    return I18n.l(month, format: "%b") if months.map(&:year).uniq.one?

    I18n.l(month, format: "%b '%y")
  end
end
