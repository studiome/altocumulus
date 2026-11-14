class HospitalizationDiagnosis < ApplicationRecord
  include LiveUpdatable
  include AuditsAssociatedChanges

  audits_associated_changes_to :hospitalization, foreign_key: :hospitalization_id

  belongs_to :hospitalization
  belongs_to :diagnosis

  delegate :name, to: :diagnosis, prefix: true

  def live_update_dates
    hospitalization&.live_update_dates || []
  end

  def live_update_records
    hospitalization&.live_update_records || []
  end
end
