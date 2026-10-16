# The data download page (index) lists every configured export with a from / to
# form; show downloads one of the configured CSV exports (SiteConfig#export_definitions)
# for the range and filters it is given (see ExportSource). Patient
# data leaves the app here, so it is limited to admins and data managers and
# every download is written to the access log (who, when, and in last_url
# which export, range and filters).
class ExportsController < ApplicationController
  before_action :require_data_exporter

  def index
    @definitions = SiteConfig.current.export_definitions
    @from = Date.current.beginning_of_month
    @to = Date.current.end_of_month
    @teams = SiteConfig.current.teams_enabled? ? Team.active.ordered : []
  end

  def show
    definition = SiteConfig.current.export_definition(params[:key])
    return head :not_found unless definition

    source = ExportSource.resolve(definition, view: params[:view], params: params, user: current_user)
    csv = CsvExport.new(definition, source.records).to_csv
    record_access_log(user: current_user, event: "export")
    send_data csv, filename: CsvExport.filename(definition, from: source.from, to: source.to),
                   type: "text/csv; charset=utf-8", disposition: "attachment"
  rescue ExportSource::Unavailable
    head :not_found
  rescue OperationsCalendar::InvalidRangeError
    # A bad from / to comes from the download page, a bad start / days from a
    # hand-made calendar link.
    if params[:from].present? || params[:to].present?
      redirect_to exports_path, alert: t("exports.index.invalid_range")
    else
      redirect_to operations_calendar_path, alert: t("operations_calendar.index.alert")
    end
  end
end
