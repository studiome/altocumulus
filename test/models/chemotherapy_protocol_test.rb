require "test_helper"
require "support/master_record_model_tests"

class ChemotherapyProtocolTest < ActiveSupport::TestCase
  include MasterRecordModelTests

  def master_class = ChemotherapyProtocol
  def used_fixture = chemotherapy_protocols(:protocol_a)
  def unused_name = "Brand New Protocol"

  setup do
    hospitalizations(:one).update_columns(purpose: "chemotherapy", chemotherapy_protocol_id: chemotherapy_protocols(:protocol_a).id)
  end

  test "a protocol used by a hospitalization is refused on delete with an error" do
    protocol = chemotherapy_protocols(:protocol_a)
    assert_not protocol.destroy
    assert_predicate protocol.errors, :any?
  end
end
