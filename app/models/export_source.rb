# Which records a CSV export covers, resolved from the request params of the
# screen the export was started from, so the file holds exactly what that
# screen shows:
#   surgery           the operations calendar's surgery tab: surgeries dated
#                     in start/days, under the mine / team_id filter
#   examination       its examination tab: the non-surgery admissions listed
#                     there, same range and filter
#   hospitalizations  the hospitalization list: Hospitalization.filtered with
#                     the list's own filter params (keyword, diagnosis_id,
#                     status, admitted_from, admitted_to)
# `from` / `to` are the covered dates as the file name shows them (nil = open).
class ExportSource
  VIEWS = %w[surgery examination hospitalizations].freeze
  SUBJECTS = { "surgery" => :surgery, "examination" => :hospitalization, "hospitalizations" => :hospitalization }.freeze
  HOSPITALIZATION_FILTERS = %i[keyword diagnosis_id status admitted_from admitted_to].freeze

  class Unavailable < StandardError; end

  Result = Data.define(:records, :from, :to)

  # Raises Unavailable for an unknown view or a view the definition's subject
  # does not fit, OperationsCalendar::InvalidRangeError for a bad range.
  def self.resolve(definition, view:, params:, user:)
    view = view.to_s
    raise Unavailable unless SUBJECTS[view] == definition.subject

    includes = definition.includes
    case view
    when "surgery" then surgeries(params, user, includes)
    when "examination" then examinations(params, user, includes)
    else hospitalizations(params, includes)
    end
  end

  def self.surgeries(params, user, includes)
    start, days = OperationsCalendar.parse_range(start: params[:start], days: params[:days])
    dates = (start..(start + days - 1)).to_a
    filter = CalendarFilter.from_params(params, user: user)
    scope = Surgery.where(surgery_date: dates)
    ids = filter.surgery_ids(dates)
    scope = scope.where(id: ids.to_a) if ids
    records = scope.includes(*includes).order(:surgery_date, :start_time, :slot_number, :id).to_a
    Result.new(records: records, from: dates.first, to: dates.last)
  end

  def self.examinations(params, user, includes)
    start, days = OperationsCalendar.parse_range(start: params[:start], days: params[:days])
    dates = (start..(start + days - 1)).to_a
    scope = ExaminationCalendar.scope_for(dates, filter: CalendarFilter.from_params(params, user: user))
    records = ExaminationCalendar.order_scope(scope.includes(*includes)).to_a
    Result.new(records: records, from: dates.first, to: dates.last)
  end

  def self.hospitalizations(params, includes)
    filters = params.permit(*HOSPITALIZATION_FILTERS).to_h.symbolize_keys.compact_blank
    records = Hospitalization.filtered(**filters)
                             .includes(*includes)
                             .order(Arel.sql("COALESCE(hospitalizations.admission_date, hospitalizations.scheduled_admission_date) ASC"), created_at: :asc)
                             .to_a
    Result.new(records: records, from: parse_date(filters[:admitted_from]), to: parse_date(filters[:admitted_to]))
  end

  def self.parse_date(value)
    Date.iso8601(value) if value
  rescue Date::Error
    nil
  end
  private_class_method :surgeries, :examinations, :hospitalizations, :parse_date
end
