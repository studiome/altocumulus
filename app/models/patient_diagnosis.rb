class PatientDiagnosis < ApplicationRecord
  include LiveUpdatable
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

  # The patient's record for this diagnosis and laterality: the existing one,
  # else a new one dated `diagnosed_on`. Never makes a duplicate.
  def self.reuse_or_create_for(patient_id:, diagnosis_id:, laterality:, diagnosed_on:)
    find_by(patient_id: patient_id, diagnosis_id: diagnosis_id, laterality: laterality) ||
      create!(patient_id: patient_id, diagnosis_id: diagnosis_id, laterality: laterality, diagnosed_on: diagnosed_on)
  end

  def display_name
    return diagnosis_name if laterality == "none"

    prefix = Lateralizable.laterality_options[laterality] || ""
    [ prefix, diagnosis_name ].reject(&:blank?).join(" ")
  end

  def to_s
    display_name
  end

  def live_update_dates
    surgeries.pluck(:surgery_date)
  end

  def live_update_records
    live_update_values(:patient_id).map { |pid| live_update_key("Patient", pid) } +
      surgeries.pluck(:id).map { |sid| live_update_key("Surgery", sid) }
  end
end
