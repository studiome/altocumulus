require "test_helper"
require "support/master_record_model_tests"

class SurgeryLocationTest < ActiveSupport::TestCase
  include MasterRecordModelTests

  def master_class = SurgeryLocation
  def used_fixture = surgery_locations(:cath_lab)
  def unused_name = "Brand New Room"

  setup do
    surgeries(:one).update_columns(surgery_location_id: surgery_locations(:cath_lab).id)
  end
end
