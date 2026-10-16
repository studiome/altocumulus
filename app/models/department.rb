# A clinical department (診療科). Referenced from surgeries as the partner
# department of a joint/backup case; later stages reference it from
# hospitalizations and surgeries (performing department) as well.
class Department < ApplicationRecord
  include MasterRecord

  has_many :surgeries, dependent: :restrict_with_error
end
