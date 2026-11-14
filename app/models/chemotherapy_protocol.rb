# A treatment protocol (regimen, 化学療法プロトコル) chosen on hospitalizations
# whose purpose uses one (see Hospitalization::PROTOCOL_PURPOSE_KEYS).
class ChemotherapyProtocol < ApplicationRecord
  include MasterRecord

  has_many :hospitalizations, dependent: :restrict_with_error
end
