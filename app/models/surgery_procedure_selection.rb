class SurgeryProcedureSelection < ApplicationRecord
  belongs_to :surgery
  belongs_to :surgery_procedure

  attribute :laterality, :string, default: "none"

  LATERALITY_OPTIONS = {
    "right" => "Right",
    "left" => "Left",
    "bilateral" => "Bilateral",
    "none" => "None"
  }.freeze

  validates :laterality, inclusion: { in: LATERALITY_OPTIONS.keys }

  def procedure_name
    surgery_procedure&.name
  end

  def display_name
    name = procedure_name
    return nil if name.blank?
    return name if laterality == "none"

    prefix = LATERALITY_OPTIONS[laterality] || ""
    prefix.present? ? "#{prefix} #{name}" : name
  end

  def laterality_label
    LATERALITY_OPTIONS[laterality] || "None"
  end
end
