# A place a surgery is performed besides the main operating rooms (実施場所).
class SurgeryLocation < ApplicationRecord
  include MasterRecord

  has_many :surgeries, dependent: :restrict_with_error
  # After the restrict above, so a record in use is refused before its rules go.
  include SpecialSlotResource

  # asks_performing_department is a hint for the surgery form: when set, offer
  # the performing-department control for cases at this place (e.g. a cath lab
  # used by several departments).
  def self.extra_form_attributes
    super + %i[asks_performing_department]
  end
end
