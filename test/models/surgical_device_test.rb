require "test_helper"
require "support/master_record_model_tests"

class SurgicalDeviceTest < ActiveSupport::TestCase
  include MasterRecordModelTests

  def master_class = SurgicalDevice
  def used_fixture = surgical_devices(:robot_a)
  def unused_name = "Brand New Device"

  setup do
    surgeries(:one).update_columns(surgical_device_id: surgical_devices(:robot_a).id)
  end
end
