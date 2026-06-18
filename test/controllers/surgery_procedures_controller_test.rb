require "test_helper"

class SurgeryProceduresControllerTest < ActionDispatch::IntegrationTest
  setup do
    @surgery_procedure = surgery_procedures(:appendectomy)
  end

  test "should get index" do
    get surgery_procedures_url
    assert_response :success
  end

  test "should get new" do
    get new_surgery_procedure_url
    assert_response :success
  end

  test "should create surgery procedure" do
    assert_difference("SurgeryProcedure.count") do
      post surgery_procedures_url, params: { surgery_procedure: { name: "Laparoscopy" } }
    end

    assert_redirected_to surgery_procedure_url(SurgeryProcedure.last)
  end

  test "should show surgery procedure" do
    get surgery_procedure_url(@surgery_procedure)
    assert_response :success
  end

  test "should get edit" do
    get edit_surgery_procedure_url(@surgery_procedure)
    assert_response :success
  end

  test "should update surgery procedure" do
    patch surgery_procedure_url(@surgery_procedure), params: { surgery_procedure: { name: "Updated Appendectomy" } }

    assert_redirected_to surgery_procedure_url(@surgery_procedure)
    @surgery_procedure.reload
    assert_equal "Updated Appendectomy", @surgery_procedure.name
    assert_equal "Updated Appendectomy", surgeries(:one).reload.procedure
  end

  test "should destroy surgery procedure" do
    assert_difference("SurgeryProcedure.count", -1) do
      delete surgery_procedure_url(surgery_procedures(:updated_procedure))
    end

    assert_redirected_to surgery_procedures_url
  end

  test "should not destroy surgery procedure in use" do
    assert_no_difference("SurgeryProcedure.count") do
      delete surgery_procedure_url(@surgery_procedure)
    end

    assert_redirected_to surgery_procedure_url(@surgery_procedure)
    assert_not_nil flash[:alert]
  end
end
