# Backs the examination-admission tab of the operations calendar: active
# hospitalizations whose purpose is not surgery, laid out by day over the same
# kind of date range as OperationsCalendar. A hospitalization sits on its
# scheduled procedure date, or its effective admission date when it has none;
# within a day they run in admission date then id order.
#
# Like OperationsCalendar it resolves everything up front in a fixed number of
# queries (one for the rows with what the configured columns read, one for the
# admission counts, plus the filter's own), however many days or rows there are.
class ExaminationCalendar
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
    @columns = LedgerColumn.for_ledger(:examination_calendar)
    @admission_counts = Hospitalization.admission_counts_on(@dates)
    @holidays = Holiday.by_date(@dates)
    @by_date = load_rows.group_by { |hospitalization| row_date(hospitalization) }
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

  def admission_warning?(date)
    admission_count_for(date) > admission_warning_threshold
  end

  # The patient column links to the hospitalization.
  def ledger_context
    LedgerColumn::Context.new(href: ->(hospitalization) { Rails.application.routes.url_helpers.hospitalization_path(hospitalization) })
  end

  private

    def row_date(hospitalization)
      hospitalization.scheduled_procedure_date || hospitalization.effective_admission_date
    end

    def load_rows
      date_sql = Arel.sql("COALESCE(hospitalizations.scheduled_procedure_date, hospitalizations.admission_date, hospitalizations.scheduled_admission_date)")
      scope = Hospitalization.active.where.not(purpose: "surgery").where(date_sql.in(dates))
      scope = filter.apply_to_hospitalizations(scope)
      scope.includes(:patient, *LedgerColumn.includes_for(columns))
           .order(Arel.sql("COALESCE(hospitalizations.admission_date, hospitalizations.scheduled_admission_date)"), :id)
           .to_a
    end
end
