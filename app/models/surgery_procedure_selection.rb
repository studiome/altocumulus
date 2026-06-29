class SurgeryProcedureSelection < ApplicationRecord
  include Lateralizable

  belongs_to :surgery
  belongs_to :surgery_procedure

  attribute :laterality, :string, default: "none"

  def procedure_name
    surgery_procedure&.name
  end

  def display_name
    name = procedure_name
    return nil if name.blank?
    return name if laterality == "none"

    prefix = Lateralizable::LATERALITY_OPTIONS[laterality] || ""
    prefix.present? ? "#{prefix} #{name}" : name
  end
end
