# A month grid of scheduled admission counts for the reservation form's side
# panel: how many non-deleted hospitalizations fall on each day (by effective
# admission date, the actual one if present, otherwise the scheduled one), and
# which days are over the configured warning threshold. The whole visible grid
# (the month plus the neighbouring days that fill its first and last week) is
# counted in one query.
class AdmissionCalendar
  EFFECTIVE_DATE = "COALESCE(hospitalizations.admission_date, hospitalizations.scheduled_admission_date)".freeze

  attr_reader :month, :threshold

  # "2026-11" or any ISO date inside the month; anything else is this month.
  def self.parse_month(value)
    text = value.is_a?(String) ? value : ""
    date = Date.iso8601(text.match?(/\A\d{4}-\d{2}\z/) ? "#{text}-01" : text)
    date.beginning_of_month
  rescue Date::Error
    Date.current.beginning_of_month
  end

  def self.count_on(date)
    Hospitalization.active.where("#{EFFECTIVE_DATE} = ?", date).count
  end

  def initialize(month:, threshold: Rails.application.config.x.admission_warning_threshold)
    @month = month.beginning_of_month
    @threshold = threshold
  end

  # Sunday-first weeks covering the month.
  def weeks
    @weeks ||= grid_dates.each_slice(7).to_a
  end

  def count_for(date)
    counts[date] || 0
  end

  def over_threshold?(date)
    count_for(date) > threshold
  end

  def in_month?(date)
    date.year == month.year && date.month == month.month
  end

  def previous_month
    month.prev_month
  end

  def next_month
    month.next_month
  end

  private

    def grid_dates
      first = month.beginning_of_week(:sunday)
      last = month.end_of_month.end_of_week(:sunday)
      (first..last).to_a
    end

    def counts
      @counts ||= Hospitalization.active
                                 .where("#{EFFECTIVE_DATE} BETWEEN ? AND ?", grid_dates.first, grid_dates.last)
                                 .group(Arel.sql(EFFECTIVE_DATE))
                                 .count
                                 .transform_keys { |key| key.is_a?(Date) ? key : Date.iso8601(key.to_s) }
    end
end
