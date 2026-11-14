# A treatment protocol (regimen, 化学療法プロトコル) chosen on hospitalizations
# whose purpose uses one (see Hospitalization::PROTOCOL_PURPOSE_KEYS).
class ChemotherapyProtocol < ApplicationRecord
  include MasterRecord

  has_many :hospitalizations, dependent: :restrict_with_error

  # Keyword search for the picker modal (a literal match on the name).
  def self.filtered(keyword: nil)
    return all if keyword.blank?

    where(like_condition("name"), pattern: like_pattern(keyword))
  end
end
