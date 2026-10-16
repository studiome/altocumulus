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
# The data download page (ExportsController#index) has no calendar to borrow a
# range from, so every view also takes `from` / `to` (ISO dates, both required,
# at most MAX_DAYS apart) in place of start/days (surgery, examination) or
# admitted_from/admitted_to (hospitalizations); the hospitalization list also
# takes `team_id` (an id or "undecided") there. A bad pair raises
# OperationsCalendar::InvalidRangeError.
# `from` / `to` in the Result are the covered dates as the file name shows them (nil = open).
class ExportSource
  VIEWS = %w[surgery examination hospitalizations].freeze
  SUBJECTS = { "surgery" => :surgery, "examination" => :hospitalization, "hospitalizations" => :hospitalization }.freeze
  HOSPITALIZATION_FILTERS = %i[keyword diagnosis_id status admitted_from admitted_to].freeze
  MAX_DAYS = 366

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
    dates = dates_for(params)
    filter = CalendarFilter.from_params(params, user: user)
    scope = Surgery.where(surgery_date: dates)
    ids = filter.surgery_ids(dates)
    scope = scope.where(id: ids.to_a) if ids
    records = scope.includes(*includes).order(:surgery_date, :start_time, :slot_number, :id).to_a
    Result.new(records: records, from: dates.first, to: dates.last)
  end

  def self.examinations(params, user, includes)
    dates = dates_for(params)
    scope = ExaminationCalendar.scope_for(dates, filter: CalendarFilter.from_params(params, user: user))
    records = ExaminationCalendar.order_scope(scope.includes(*includes)).to_a
    Result.new(records: records, from: dates.first, to: dates.last)
  end

  def self.hospitalizations(params, includes)
    filters = params.permit(*HOSPITALIZATION_FILTERS).to_h.symbolize_keys.compact_blank
    if download_range?(params)
      from, to = download_range(params)
      filters.merge!(admitted_from: from.iso8601, admitted_to: to.iso8601)
    end
    scope = Hospitalization.filtered(**filters)
    scope = with_team(scope, params[:team_id])
    records = scope.includes(*includes)
                   .order(Arel.sql("COALESCE(hospitalizations.admission_date, hospitalizations.scheduled_admission_date) ASC"), created_at: :asc)
                   .to_a
    Result.new(records: records, from: parse_date(filters[:admitted_from]), to: parse_date(filters[:admitted_to]))
  end

  # The dates a calendar-based view covers: from / to when given, else the
  # calendar's start / days.
  def self.dates_for(params)
    if download_range?(params)
      from, to = download_range(params)
      (from..to).to_a
    else
      start, days = OperationsCalendar.parse_range(start: params[:start], days: params[:days])
      (start..(start + days - 1)).to_a
    end
  end

  def self.download_range?(params)
    params[:from].present? || params[:to].present?
  end

  def self.download_range(params)
    from = Date.iso8601(params[:from].to_s)
    to = Date.iso8601(params[:to].to_s)
    raise OperationsCalendar::InvalidRangeError unless to >= from && (to - from).to_i < MAX_DAYS

    [ from, to ]
  rescue Date::Error
    raise OperationsCalendar::InvalidRangeError
  end

  def self.with_team(scope, raw)
    return scope unless SiteConfig.current.teams_enabled?

    raw = raw.to_s
    if raw == CalendarFilter::UNDECIDED then scope.where(team_id: nil, team_undecided: true)
    elsif raw.match?(/\A\d+\z/) then scope.where(team_id: raw.to_i)
    else scope
    end
  end

  def self.parse_date(value)
    Date.iso8601(value) if value
  rescue Date::Error
    nil
  end
  private_class_method :surgeries, :examinations, :hospitalizations, :dates_for, :download_range?, :download_range, :with_team, :parse_date
end
