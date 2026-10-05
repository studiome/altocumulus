# Backs the operations calendar screen: a day-by-day view of elective slot
# usage, admission load and holidays/comments, spanning a configurable date
# range.
#
# Modeled after LedgerStatistics and ElectiveSlotUsage: a plain object built
# once per request that resolves everything it needs up front in a fixed
# number of queries, independent of how many days are in the range (see
# ElectiveSlotUsage.for_dates, which this reuses rather than re-querying
# surgeries/holidays/rules itself).
class OperationsCalendar
  MAX_DAYS = 120
  DEFAULT_DAYS = 50
  DEFAULT_LOOKBACK_DAYS = 7

  InvalidRangeError = Class.new(StandardError)

  # The range shown when no start/days are given.
  def self.default_start
    Date.current - DEFAULT_LOOKBACK_DAYS
  end

  def self.default_range
    default_start..(default_start + DEFAULT_DAYS - 1)
  end

  attr_reader :start_date, :days, :dates, :slot_usages, :admission_counts,
              :admission_warning_threshold

  # Parses the raw (and possibly invalid or crafted) request params into a
  # valid range before building the calendar, so a bad `start` or `days`
  # never reaches Date.parse/Integer directly in the controller and blows up
  # with an unhandled exception -- it becomes InvalidRangeError instead,
  # which the controller turns into a redirect.
  def self.build(start: nil, days: nil)
    new(start_date: parse_start(start), days: parse_days(days))
  end

  def initialize(start_date:, days:)
    @start_date = start_date
    @days = days
    @dates = (start_date..(start_date + days - 1)).to_a
    @admission_warning_threshold = Rails.application.config.x.admission_warning_threshold

    @slot_usages = ElectiveSlotUsage.for_dates(@dates)
    @admission_counts = build_admission_counts
    @referral_lookup = build_referral_lookup
  end

  # The referral source of the patient's hospitalization whose period covers
  # the surgery date, or nil when there is none (or it has no referral).
  def referred_from_for(surgery)
    @referral_lookup.referred_from_for(surgery)
  end

  def admission_count_for(date)
    admission_counts[date] || 0
  end

  def admission_warning?(date)
    admission_count_for(date) > admission_warning_threshold
  end

  private

    def self.parse_start(value)
      return default_start if value.blank?

      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      raise InvalidRangeError
    end
    private_class_method :parse_start

    def self.parse_days(value)
      return DEFAULT_DAYS if value.blank?

      parsed = Integer(value.to_s, exception: false)
      raise InvalidRangeError if parsed.nil? || !parsed.between?(1, MAX_DAYS)

      parsed
    end
    private_class_method :parse_days

    def effective_date_order
      Arel.sql("COALESCE(hospitalizations.admission_date, hospitalizations.scheduled_admission_date)")
    end

    # One group(...).count query regardless of how many dates are in `dates`
    # (it compiles to a single WHERE effective_date IN (...) GROUP BY), keyed
    # by the same effective_admission_date (actual if present, otherwise
    # scheduled) that the rest of the app already treats as the single
    # canonical date of a hospitalization -- see Hospitalization#upcoming,
    # #admitted_between, and #no_overlapping_hospitalization_period. Each
    # hospitalization is counted exactly once, on that one day, never on both
    # its scheduled and actual dates.
    def build_admission_counts
      # effective_date_order is our own fixed SQL fragment (not user input),
      # but building the IN clause via Arel's #in -- rather than interpolating
      # it into a "... IN (?)" string -- keeps `dates` properly bound instead
      # of string-substituted, which is both correct and what satisfies
      # Brakeman's SQL-injection check on this line.
      counts = Hospitalization.active
                               .where(effective_date_order.in(dates))
                               .group(effective_date_order)
                               .count

      counts.transform_keys { |date| date.is_a?(Date) ? date : Date.parse(date.to_s) }
    end

    # One query for every surgery on the calendar, narrowed by the range as a
    # whole (see SurgeryReferralLookup).
    def build_referral_lookup
      patient_ids = slot_usages.values.flat_map { |usage| (usage.elective_surgeries + usage.emergency_surgeries).map(&:patient_id) }.uniq

      SurgeryReferralLookup.new(patient_ids: patient_ids, dates: dates)
    end
end
