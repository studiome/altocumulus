# Backs the admission tab of the operations calendar: every active
# hospitalization, whatever its purpose, laid out by day over the same kind of
# date range as OperationsCalendar. A hospitalization sits on its effective
# admission date (the actual admission date, else the scheduled one), which is
# also the date Hospitalization.admission_counts_on counts, so the day's count
# here equals the one the other tabs show. Within a day rows run in purpose
# (alphabetical key) then id order, which keeps same-purpose admissions together.
# Not to be confused with AdmissionCalendar, the reservation side-panel month grid.
#
# Like ExaminationCalendar it resolves everything up front in a fixed number of
# queries (one for the rows with what the configured columns read, one for the
# admission counts, plus the filter's own), however many days or rows there are.
class AdmissionLedgerCalendar
  EFFECTIVE_DATE_SQL = "COALESCE(hospitalizations.admission_date, hospitalizations.scheduled_admission_date)".freeze

  attr_reader :start_date, :days, :dates, :columns, :filter, :return_start, :return_days, :admission_warning_threshold

  def self.build(start: nil, days: nil, filter: CalendarFilter.none)
    start_date, days = OperationsCalendar.parse_range(start: start, days: days)
    new(start_date: start_date, days: days, filter: filter)
  end

  def initialize(start_date:, days:, filter: CalendarFilter.none, return_start: start_date, return_days: days)
    @start_date = start_date
    @days = days
    @filter = filter
    @return_start = return_start
    @return_days = return_days
    @dates = (start_date..(start_date + days - 1)).to_a
    @admission_warning_threshold = Rails.application.config.x.admission_warning_threshold
    @columns = LedgerColumn.for_ledger(:admission_calendar)
    @admission_counts = Hospitalization.admission_counts_on(@dates)
    @holidays = Holiday.by_date(@dates)
    @by_date = load_rows.group_by(&:effective_admission_date)
  end

  # The hospitalizations the tab lists for `dates` (before any preloading or
  # ordering): active, admitted on one of the dates, narrowed by the filter.
  # Shared with the CSV export, which must list the same rows.
  def self.scope_for(dates, filter: CalendarFilter.none)
    scope = Hospitalization.active.where(Arel.sql(EFFECTIVE_DATE_SQL).in(dates))
    filter.apply_to_hospitalizations(scope)
  end

  def self.order_scope(scope)
    scope.order(Arel.sql(EFFECTIVE_DATE_SQL), :purpose, :id)
  end

  def hospitalizations_for(date)
    @by_date[date] || []
  end

  def holiday_for(date)
    @holidays[date]
  end

  def admission_count_for(date)
    @admission_counts[date] || 0
  end

  def admission_warning?(date)
    admission_count_for(date) > admission_warning_threshold
  end

  # The patient column links to the reservation form.
  def ledger_context
    LedgerColumn::Context.new(href: ->(hospitalization) { Rails.application.routes.url_helpers.edit_reservation_path(hospitalization) })
  end

  private

    def load_rows
      scope = self.class.scope_for(dates, filter: filter)
      self.class.order_scope(scope.includes(:patient, *LedgerColumn.includes_for(columns))).to_a
    end
end
