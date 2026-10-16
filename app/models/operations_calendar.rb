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
              :admission_warning_threshold, :columns, :filter, :return_start, :return_days

  # Parses the raw (and possibly invalid or crafted) request params into a
  # valid range before building the calendar, so a bad `start` or `days`
  # never reaches Date.parse/Integer directly in the controller and blows up
  # with an unhandled exception -- it becomes InvalidRangeError instead,
  # which the controller turns into a redirect.
  def self.build(start: nil, days: nil, filter: CalendarFilter.none)
    new(start_date: parse_start(start), days: parse_days(days), filter: filter)
  end

  # The validated [start_date, days] for raw params; shared with
  # ExaminationCalendar so both tabs accept exactly the same ranges.
  def self.parse_range(start: nil, days: nil)
    [ parse_start(start), parse_days(days) ]
  end

  # `return_start` / `return_days` are the range the screen was opened with,
  # which the surgery links carry back (a single day re-rendered by the day
  # note editor still belongs to the whole range).
  def initialize(start_date:, days:, filter: CalendarFilter.none, return_start: start_date, return_days: days)
    @start_date = start_date
    @days = days
    @filter = filter
    @return_start = return_start
    @return_days = return_days
    @dates = (start_date..(start_date + days - 1)).to_a
    @admission_warning_threshold = Rails.application.config.x.admission_warning_threshold

    @columns = LedgerColumn.for_ledger(:operations_calendar)
    @slot_usages = ElectiveSlotUsage.for_dates(@dates, includes: LedgerColumn.includes_for(@columns))
    @admission_counts = Hospitalization.admission_counts_on(@dates)
    @shown_surgery_ids = filter.surgery_ids(@dates)
    @referral_lookup = build_referral_lookup
  end

  # The surgeries of the day to list, elective then emergency. Under a filter
  # only the matching ones (matched in SQL, see CalendarFilter); the day's slot
  # usage numbers still count every case.
  def surgeries_for(date)
    usage = slot_usages[date]
    surgeries = usage.elective_surgeries + usage.emergency_surgeries
    @shown_surgery_ids ? surgeries.select { |surgery| @shown_surgery_ids.include?(surgery.id) } : surgeries
  end

  # The referral source of the patient's hospitalization whose period covers
  # the surgery date, or nil when there is none (or it has no referral).
  def referred_from_for(surgery)
    @referral_lookup.referred_from_for(surgery)
  end

  # What the ledger column builders need besides the record; `href` makes the
  # patient column link to a surgery.
  def ledger_context(href: nil)
    LedgerColumn::Context.new(referral_lookup: @referral_lookup, href: href)
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

    # One query for every surgery on the calendar, narrowed by the range as a
    # whole (see SurgeryReferralLookup).
    def build_referral_lookup
      patient_ids = dates.flat_map { |date| surgeries_for(date).map(&:patient_id) }.uniq

      SurgeryReferralLookup.new(patient_ids: patient_ids, dates: dates)
    end
end
