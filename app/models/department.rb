# A clinical department (診療科). Referenced from surgeries as the partner
# department of a joint/backup case and as the performing department, and from
# hospitalizations as the department a transferred patient came from.
class Department < ApplicationRecord
  include MasterRecord

  has_many :surgeries, dependent: :restrict_with_error
  has_many :performed_surgeries, class_name: "Surgery", foreign_key: :performing_department_id,
                                 inverse_of: :performing_department, dependent: :restrict_with_error
  has_many :transferred_hospitalizations, class_name: "Hospitalization", foreign_key: :source_department_id,
                                          inverse_of: :source_department, dependent: :restrict_with_error
end
