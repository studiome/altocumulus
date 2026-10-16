# A place a surgery is performed besides the main operating rooms (実施場所).
class SurgeryLocation < ApplicationRecord
  include MasterRecord

  has_many :surgeries, dependent: :restrict_with_error
end
