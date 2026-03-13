class Patient < ApplicationRecord
  has_many :surgeries, dependent: :destroy
  validates :hospital_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :date_of_birth, presence: true
end
