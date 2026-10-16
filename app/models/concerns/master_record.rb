# Shared behavior of the admin-editable lists of site vocabulary (Department,
# SurgeryLocation, SurgicalDevice): a unique name, a manual display order and
# an active flag. Nothing site-specific lives in code; the rows come from the
# admin screens, optionally seeded from the site config (SiteMasterSeeder).
#
# Deactivating hides a record from the choices offered for NEW selections, but
# records that already reference it keep showing it, and `choices_for` keeps it
# selectable on that record's edit form so saving does not drop the value.
# Deleting a record that is still referenced is refused (restrict_with_error on
# the including model's associations).
module MasterRecord
  extend ActiveSupport::Concern

  included do
    normalizes :name, with: ->(name) { name.strip }

    validates :name, presence: true, uniqueness: true

    before_validation :assign_next_position, on: :create

    scope :ordered, -> { order(:position, :name) }
    scope :active, -> { where(active: true) }
  end

  class_methods do
    # Attributes besides name/position/active the master's admin form edits;
    # a model that has some overrides this (see SurgeryLocation).
    def extra_form_attributes
      []
    end

    # The records a form may offer: every active one, plus the one the record
    # being edited already points at (even if it has been deactivated since).
    def choices_for(current_id)
      return ordered.active if current_id.blank?

      ordered.where(active: true).or(ordered.where(id: current_id))
    end
  end

  def to_s
    name.to_s
  end

  private

    def assign_next_position
      self.position ||= (self.class.maximum(:position) || 0) + 1
    end
end
