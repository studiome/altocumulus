# The rule that decides which hospitalization a surgery date belongs to,
# shared by SurgeryReferralLookup (calendar, weekly PDF) and the migration
# backfill that linked existing surgeries (SurgeryHospitalizationBackfill).
# Plain Ruby on purpose: it works on anything period-shaped (a Hospitalization,
# or a Period built from raw SQL rows), so neither caller needs the other's
# models.
module HospitalizationCoverage
  # The three facts the rule reads. A Hospitalization answers all of them.
  Period = Struct.new(:scheduled_surgery_date, :effective_admission_date, :discharge_date, keyword_init: true)

  # A hospitalization belongs to a surgery's day when its period spans the
  # day, or when that day is the surgery date it was booked for.
  def self.covers?(period, date)
    return true if period.scheduled_surgery_date == date

    start = period.effective_admission_date
    start.present? && start <= date && (period.discharge_date.nil? || period.discharge_date >= date)
  end
end
