# Resolves the referral source (hospitalizations.referred_from) shown beside a
# surgery, shared by the operations calendar and the weekly schedule PDF.
#
# A surgery linked to a hospitalization (surgeries.hospitalization_id) uses
# that one. For the rest the lookup is built once from the patients and date
# range a screen covers: a single query loads only the active, referred
# hospitalizations that could matter, and which one belongs to which surgery
# is then decided in Ruby (see HospitalizationCoverage), so the query count
# does not grow with the number of surgeries. Callers preload
# `surgery.hospitalization` along with the surgeries.
class SurgeryReferralLookup
  def initialize(patient_ids:, dates:)
    dates = dates.to_a.compact
    @referrals_by_patient = dates.empty? ? {} : load_referrals(patient_ids.to_a.uniq, dates.min, dates.max)
  end

  # The referral source of the surgery's linked hospitalization or, when it
  # is not linked (or the link was discarded), of the patient's hospitalization
  # whose period covers the surgery date; nil when there is none (or it has no
  # referral). An unlinked, undated surgery has no day to match, so it never
  # has a referral source.
  def referred_from_for(surgery)
    linked = surgery.hospitalization
    return linked.referred_from if linked && !linked.deleted?
    return nil if surgery.surgery_date.nil?

    @referrals_by_patient.fetch(surgery.patient_id, []).find { |hospitalization|
      HospitalizationCoverage.covers?(hospitalization, surgery.surgery_date)
    }&.referred_from
  end

  private

    def load_referrals(patient_ids, first, last)
      Hospitalization.active.referred
                     .where(patient_id: patient_ids)
                     .where(
                       "(COALESCE(hospitalizations.admission_date, hospitalizations.scheduled_admission_date) <= :last " \
                       "AND (hospitalizations.discharge_date IS NULL OR hospitalizations.discharge_date >= :first)) " \
                       "OR hospitalizations.scheduled_surgery_date BETWEEN :first AND :last",
                       first: first, last: last
                     )
                     .group_by(&:patient_id)
    end
end
