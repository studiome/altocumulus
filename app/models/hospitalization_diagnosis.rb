class HospitalizationDiagnosis < ApplicationRecord
  include AuditsAssociatedChanges

  audits_associated_changes_to :hospitalization, foreign_key: :hospitalization_id

  belongs_to :hospitalization
  belongs_to :diagnosis

  delegate :name, to: :diagnosis, prefix: true
end
