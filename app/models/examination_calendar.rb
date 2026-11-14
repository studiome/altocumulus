# Backs the examination-admission tab of the operations calendar: active
# hospitalizations whose purpose is neither surgery nor one that has its own
# tab (Hospitalization::PROTOCOL_PURPOSE_KEYS, see ChemotherapyCalendar),
# laid out by day over the same kind of date range as OperationsCalendar.
# ChemotherapyCalendar subclasses this and only changes which purposes, which
# ledger, and the names the shared day partial asks for. A hospitalization sits on its
# scheduled procedure date, or its effective admission date when it has none;
# within a day they run in admission date then id order.
#
# Like OperationsCalendar it resolves everything up front in a fixed number of
# queries (one for the rows with what the configured columns read, one for the
# admission counts, plus the filter's own), however many days or rows there are.
class ExaminationCalendar
  attr_reader :start_date, :days, :dates, :columns, :filter, :return_start, :return_days

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
    @columns = LedgerColumn.for_ledger(self.class.ledger)
    @admission_counts = Hospitalization.admission_counts_on(@dates)
    @holidays = Holiday.by_date(@dates)
    @admission_thresholds = AdmissionThreshold.for_dates(@dates, holidays: @holidays)
    @by_date = load_rows.group_by { |hospitalization| row_date(hospitalization) }
  end

  # The ledger (site config ledger_columns key) the tab's columns come from.
  def self.ledger
    :examination_calendar
  end

  # Narrows active hospitalizations to the purposes the tab lists.
  def self.purpose_scope(scope)
    scope.where.not(purpose: [ "surgery", *Hospitalization::PROTOCOL_PURPOSE_KEYS ])
  end

  # The hospitalizations the tab lists for `dates` (before any preloading or
  # ordering): active, of the tab's purposes, sitting on one of the dates,
  # narrowed by the filter. Shared with the CSV export, which must list the
  # same rows.
  def self.scope_for(dates, filter: CalendarFilter.none)
    date_sql = Arel.sql("COALESCE(hospitalizations.scheduled_procedure_date, hospitalizations.admission_date, hospitalizations.scheduled_admission_date)")
    scope = purpose_scope(Hospitalization.active).where(date_sql.in(dates))
    filter.apply_to_hospitalizations(scope)
  end

  def self.order_scope(scope)
    scope.order(Arel.sql("COALESCE(hospitalizations.admission_date, hospitalizations.scheduled_admission_date)"), :id)
  end

  # The tab's view name (the `view` param), and the purpose its "+入約" link
  # starts the reservation form with.
  def view_key
    "examination"
  end

  def new_reservation_purpose
    "examination"
  end

  # The key (under operations_calendar.examination_day) of the text of a day
  # without rows.
  def empty_message_key
    "no_examinations"
  end

  def hospitalizations_for(date)
    @by_date[date] || []
  end

  # The day's Holiday row (closed day or note), if any.
  def holiday_for(date)
    @holidays[date]
  end

  def admission_count_for(date)
    @admission_counts[date] || 0
  end

  # The day's admissions-per-day warning threshold (see AdmissionThreshold) and
  # whether a per-date Holiday value is what applies.
  def admission_threshold_for(date)
    @admission_thresholds.threshold_for(date)
  end

  def admission_threshold_overridden?(date)
    @admission_thresholds.overridden?(date)
  end

  def admission_warning?(date)
    admission_count_for(date) > admission_threshold_for(date)
  end

  # The patient column links to the reservation form (these are active
  # hospitalizations, which is what it edits).
  def ledger_context
    LedgerColumn::Context.new(ledger_keys: columns.map(&:key), href: ->(hospitalization) { Rails.application.routes.url_helpers.edit_reservation_path(hospitalization) })
  end

  private

    def row_date(hospitalization)
      hospitalization.scheduled_procedure_date || hospitalization.effective_admission_date
    end

    def load_rows
      scope = self.class.scope_for(dates, filter: filter)
      self.class.order_scope(scope.includes(:patient, *LedgerColumn.includes_for(columns))).to_a
    end
end
