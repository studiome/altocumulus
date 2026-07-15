class HospitalizationDiagnosis < ApplicationRecord
  belongs_to :hospitalization
  belongs_to :diagnosis

  delegate :name, to: :diagnosis, prefix: true
end
