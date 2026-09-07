class PatientDiagnosis < ApplicationRecord
  include AuditsAssociatedChanges
  include Lateralizable

  audits_associated_changes_to :patient, foreign_key: :patient_id

  belongs_to :patient
  belongs_to :diagnosis
  has_many :surgery_diagnosis_links, dependent: :restrict_with_error
  has_many :surgeries, through: :surgery_diagnosis_links

  delegate :name, to: :diagnosis, prefix: true

  validates :diagnosed_on, presence: true

  scope :recent_first, -> { order(diagnosed_on: :desc, created_at: :desc) }

  def display_name
    return diagnosis_name if laterality == "none"

    prefix = Lateralizable.laterality_options[laterality] || ""
    [ prefix, diagnosis_name ].reject(&:blank?).join(" ")
  end

  def to_s
    display_name
  end
end
