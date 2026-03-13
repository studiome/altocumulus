class Patient < ApplicationRecord
  has_many :surgeries, dependent: :destroy
end
