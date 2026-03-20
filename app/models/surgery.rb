class Surgery < ApplicationRecord
  belongs_to :patient
  belongs_to :surgery_procedure,
             class_name: "SurgeryProcedure",
             foreign_key: :procedure,
             primary_key: :name,
             optional: true

  validates :surgery_date, presence: true
  validates :procedure, presence: true
  validates :anesthesia_method, presence: true
  validates :duration_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :procedure_must_exist

  private

  def procedure_must_exist
    return if procedure.blank?
    return if SurgeryProcedure.exists?(name: procedure)

    errors.add(:procedure, "must be selected from the procedure list")
  end
end
