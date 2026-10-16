# A surgical support device (手術支援機器) a surgery can be recorded against.
class SurgicalDevice < ApplicationRecord
  include MasterRecord

  has_many :surgeries, dependent: :restrict_with_error
  # After the restrict above, so a record in use is refused before its rules go.
  include SpecialSlotResource
end
