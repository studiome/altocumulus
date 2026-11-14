# Resolves the admissions-per-day warning threshold for a date, in one place:
#
#   1. that date's Holiday#admission_threshold (closed day or note-only day)
#   2. the weekday's AdmissionThresholdRule
#   3. the deploy-wide default (config.x.admission_warning_threshold)
#
# Built once per request for all the dates on screen in a fixed number of
# queries (the rules once; the holidays once, or reused when the caller has
# them already).
class AdmissionThreshold
  def self.for_dates(dates, holidays: nil)
    dates = dates.to_a
    new(rules: AdmissionThresholdRule.thresholds_by_day, holidays: holidays || Holiday.by_date(dates))
  end

  def initialize(rules:, holidays:)
    @rules = rules
    @holidays = holidays
  end

  def threshold_for(date)
    override_for(date) || @rules[date.wday] || AdmissionThresholdRule.default_threshold
  end

  # Whether a per-date Holiday value is what applies.
  def overridden?(date)
    !override_for(date).nil?
  end

  private

    def override_for(date)
      @holidays[date]&.admission_threshold
    end
end
