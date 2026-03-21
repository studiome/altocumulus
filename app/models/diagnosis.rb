class Diagnosis < ApplicationRecord
  validates :name, presence: true, uniqueness: true
end
