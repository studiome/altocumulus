# Plain-SQL data half of the migration that added surgeries.hospitalization_id:
# links each dated surgery to the active hospitalization of the same patient
# that covers its date (HospitalizationCoverage, the same rule the calendar
# uses). Ambiguous (several cover it) or none -> left unlinked, and surgeries
# that are already linked are never touched. Free of application models and
# parameterised by table/column names, like MasterBackfill, so it keeps
# working however the models change and a test can run it on scratch tables.
class SurgeryHospitalizationBackfill
  def initialize(connection, surgeries_table: :surgeries, hospitalizations_table: :hospitalizations,
                 fk_column: :hospitalization_id)
    @connection = connection
    @surgeries_table = surgeries_table
    @hospitalizations_table = hospitalizations_table
    @fk_column = fk_column
  end

  # Returns { linked:, ambiguous:, unmatched: } counted over the dated,
  # not-yet-linked surgeries.
  def up
    periods = periods_by_patient
    result = { linked: 0, ambiguous: 0, unmatched: 0 }

    connection.select_rows(pending_surgeries).each do |surgery_id, patient_id, surgery_date|
      date = to_date(surgery_date)
      covering = periods.fetch(patient_id, []).select { |_id, period| HospitalizationCoverage.covers?(period, date) }

      case covering.size
      when 1
        link(surgery_id, covering.first.first)
        result[:linked] += 1
      when 0 then result[:unmatched] += 1
      else result[:ambiguous] += 1
      end
    end

    result
  end

  private

    attr_reader :connection

    def surgeries = (@surgeries ||= Arel::Table.new(@surgeries_table))
    def hospitalizations = (@hospitalizations ||= Arel::Table.new(@hospitalizations_table))

    def pending_surgeries
      surgeries.project(surgeries[:id], surgeries[:patient_id], surgeries[:surgery_date])
               .where(surgeries[:surgery_date].not_eq(nil)).where(surgeries[@fk_column].eq(nil)).order(surgeries[:id])
    end

    def link(surgery_id, hospitalization_id)
      update = Arel::UpdateManager.new
      update.table(surgeries)
      update.set([ [ surgeries[@fk_column], hospitalization_id ] ])
      update.where(surgeries[:id].eq(surgery_id))
      connection.update(update)
    end

    # patient_id => [[hospitalization_id, Period], ...] for active rows.
    def periods_by_patient
      columns = %i[id patient_id admission_date scheduled_admission_date scheduled_surgery_date discharge_date]
      query = hospitalizations.project(*columns.map { |column| hospitalizations[column] })
                              .where(hospitalizations[:deleted_at].eq(nil)).order(hospitalizations[:id])

      connection.select_rows(query).each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |row, grouped|
        id, patient_id, admission, scheduled, surgery, discharge = row
        period = HospitalizationCoverage::Period.new(
          scheduled_surgery_date: to_date(surgery),
          effective_admission_date: to_date(admission) || to_date(scheduled),
          discharge_date: to_date(discharge)
        )
        grouped[patient_id] << [ id, period ]
      end
    end

    def to_date(value)
      return nil if value.blank?

      value.is_a?(Date) ? value : Date.parse(value.to_s)
    end
end
