class SurgeryProcedure < ApplicationRecord
  has_many :surgery_procedure_selections, dependent: :restrict_with_error
  has_many :surgeries,
           class_name: "Surgery",
           foreign_key: :procedure,
           primary_key: :name

  validates :name, presence: true, uniqueness: true

  after_update :sync_surgery_names, if: :saved_change_to_name?

  private

  def sync_surgery_names
    Surgery.where(procedure: name_before_last_save).update_all(procedure: name)
  end
end
