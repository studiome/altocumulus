module ApplicationHelper
  # The installation's own name (see AppSetting). Memoized because the layout
  # asks for it more than once per request.
  def app_title
    @app_title ||= AppSetting.title
  end

  # A date with its weekday, coloured for days off: Saturday blue, Sunday and
  # closed days (a Holiday row with holiday: true) red. `holidays` is the
  # Holiday.by_date hash a list page loads once for all its dates; single-date
  # callers can omit it and pay one lookup. A Holiday row with holiday: false
  # is only a day comment and never colours anything.
  def date_with_weekday(date, holidays: nil)
    holiday = holidays ? holidays[date] : Holiday.find_by(date: date)
    css_class =
      if date.sunday? || holiday&.holiday?
        "app-date-holiday"
      elsif date.saturday?
        "app-date-sat"
      end

    tag.span(l(date, format: :with_weekday), class: css_class)
  end
end
