class Surgery < ApplicationRecord
  attribute :laterality, :string, default: "none"

  belongs_to :patient
  belongs_to :surgery_procedure,
             class_name: "SurgeryProcedure",
             foreign_key: :procedure,
             primary_key: :name,
             optional: true

  LATERALITY_PREFIXES = {
    "right" => "Right",
    "left" => "Left",
    "bilateral" => "Bilateral",
    "none" => ""
  }.freeze

  validates :surgery_date, presence: true
  validates :procedure, presence: true
  validates :anesthesia_method, presence: true
  validates :duration_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :laterality, inclusion: { in: LATERALITY_PREFIXES.keys }
  validate :procedure_must_exist

  def display_procedure_name
    prefix = LATERALITY_PREFIXES[laterality] || ""

    if prefix.empty?
      procedure
    else
      "#{prefix} #{procedure}"
    end
  end

  private

  def procedure_must_exist
    return if procedure.blank?
    return if SurgeryProcedure.exists?(name: procedure)

    errors.add(:procedure, "must be selected from the procedure list")
  end
end
