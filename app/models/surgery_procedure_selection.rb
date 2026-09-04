class SurgeryProcedureSelection < ApplicationRecord
  include AuditsAssociatedChanges
  include Lateralizable

  audits_associated_changes_to :surgery, foreign_key: :surgery_id

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
