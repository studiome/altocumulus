require "test_helper"
require "support/master_record_model_tests"

class DepartmentTest < ActiveSupport::TestCase
  include MasterRecordModelTests

  def master_class = Department
  def used_fixture = departments(:gynecology)
  def unused_name = "Brand New Department"

  setup do
    surgeries(:one).update_columns(department_id: departments(:gynecology).id)
  end
end
