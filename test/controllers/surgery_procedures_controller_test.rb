require "test_helper"

class SurgeryProceduresControllerTest < ActionDispatch::IntegrationTest
  TURBO_STREAM_ACCEPT = "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"

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

  test "should redirect after create when submitted from the standalone page (no Turbo-Frame header)" do
    assert_difference("SurgeryProcedure.count") do
      post surgery_procedures_url, params: { surgery_procedure: { name: "Laparoscopy" } },
                                    headers: { "Accept" => TURBO_STREAM_ACCEPT }
    end

    assert_redirected_to surgery_procedure_url(SurgeryProcedure.last)
  end

  test "should respond with turbo stream after create when submitted from the picker frame" do
    assert_difference("SurgeryProcedure.count") do
      post surgery_procedures_url, params: { surgery_procedure: { name: "Laparoscopy" } },
                                    headers: { "Accept" => TURBO_STREAM_ACCEPT, "Turbo-Frame" => "surgery_procedure_picker_frame" }
    end

    assert_response :success
    assert_equal Mime[:turbo_stream].to_s, response.media_type
  end

  test "should render html on validation failure from the standalone page (no Turbo-Frame header)" do
    assert_no_difference("SurgeryProcedure.count") do
      post surgery_procedures_url, params: { surgery_procedure: { name: "" } },
                                    headers: { "Accept" => TURBO_STREAM_ACCEPT }
    end

    assert_response :unprocessable_entity
    assert_equal Mime[:html].to_s, response.media_type
  end

  test "should respond with turbo stream on validation failure from the modal frame" do
    assert_no_difference("SurgeryProcedure.count") do
      post surgery_procedures_url, params: { surgery_procedure: { name: "" } },
                                    headers: { "Accept" => TURBO_STREAM_ACCEPT, "Turbo-Frame" => "surgery_procedure_picker_frame" }
    end

    assert_response :unprocessable_entity
    assert_equal Mime[:turbo_stream].to_s, response.media_type
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
    assert_equal "Updated Appendectomy", surgeries(:one).reload.procedure_names.first
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

  test "should get picker" do
    get picker_surgery_procedures_url

    assert_response :success
    assert_match "surgery_procedure_picker_frame", response.body
    assert_match surgery_procedures(:appendectomy).name, response.body
  end

  test "picker narrows the list by keyword" do
    get picker_surgery_procedures_url, params: { keyword: "endect" }

    assert_response :success
    assert_match surgery_procedures(:appendectomy).name, response.body
    assert_no_match(/#{surgery_procedures(:cholecystectomy).name}/, response.body)
  end

  test "should respond with the picker turbo stream after create from the picker frame" do
    assert_difference("SurgeryProcedure.count") do
      post surgery_procedures_url, params: { surgery_procedure: { name: "Laparoscopy" } },
                                    headers: { "Accept" => TURBO_STREAM_ACCEPT, "Turbo-Frame" => "surgery_procedure_picker_frame" }
    end

    assert_response :success
    assert_equal Mime[:turbo_stream].to_s, response.media_type
    assert_match "surgery_procedure_picker_frame", response.body
  end
end
