class PatientDiagnosis < ApplicationRecord
  belongs_to :patient
  belongs_to :diagnosis
  has_many :surgery_diagnosis_links, dependent: :restrict_with_error
  has_many :surgeries, through: :surgery_diagnosis_links

  LATERALITY_OPTIONS = {
    "right" => "Right",
    "left" => "Left",
    "bilateral" => "Bilateral",
    "none" => ""
  }.freeze

  delegate :name, to: :diagnosis, prefix: true

  validates :diagnosed_on, presence: true
  validates :laterality, inclusion: { in: LATERALITY_OPTIONS.keys }

  scope :recent_first, -> { order(diagnosed_on: :desc, created_at: :desc) }

  def display_name
    return diagnosis_name if laterality == "none"

    prefix = LATERALITY_OPTIONS[laterality] || ""
    [ prefix, diagnosis_name ].reject(&:blank?).join(" ")
  end

  def laterality_label
    LATERALITY_OPTIONS[laterality].presence || "None"
  end
end
