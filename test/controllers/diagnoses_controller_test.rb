require "test_helper"

class DiagnosesControllerTest < ActionDispatch::IntegrationTest
  TURBO_STREAM_ACCEPT = "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"

  setup do
    @diagnosis = diagnoses(:appendicitis)
  end

  test "should get index" do
    get diagnoses_url
    assert_response :success
  end

  test "should get new" do
    get new_diagnosis_url
    assert_response :success
  end

  test "should create diagnosis" do
    assert_difference("Diagnosis.count") do
      post diagnoses_url, params: { diagnosis: { name: "Migraine" } }
    end

    assert_redirected_to diagnosis_url(Diagnosis.last)
  end

  test "should redirect after create when submitted from the standalone page (no Turbo-Frame header)" do
    assert_difference("Diagnosis.count") do
      post diagnoses_url, params: { diagnosis: { name: "Migraine with aura" } },
                           headers: { "Accept" => TURBO_STREAM_ACCEPT }
    end

    assert_redirected_to diagnosis_url(Diagnosis.last)
  end

  test "should respond with turbo stream after create when submitted from the modal frame" do
    assert_difference("Diagnosis.count") do
      post diagnoses_url, params: { diagnosis: { name: "Migraine with aura" } },
                           headers: { "Accept" => TURBO_STREAM_ACCEPT, "Turbo-Frame" => "diagnosis_modal_frame" }
    end

    assert_response :success
    assert_equal Mime[:turbo_stream].to_s, response.media_type
  end

  test "should render html on validation failure from the standalone page (no Turbo-Frame header)" do
    assert_no_difference("Diagnosis.count") do
      post diagnoses_url, params: { diagnosis: { name: "" } },
                           headers: { "Accept" => TURBO_STREAM_ACCEPT }
    end

    assert_response :unprocessable_entity
    assert_equal Mime[:html].to_s, response.media_type
  end

  test "should respond with turbo stream on validation failure from the modal frame" do
    assert_no_difference("Diagnosis.count") do
      post diagnoses_url, params: { diagnosis: { name: "" } },
                           headers: { "Accept" => TURBO_STREAM_ACCEPT, "Turbo-Frame" => "diagnosis_modal_frame" }
    end

    assert_response :unprocessable_entity
    assert_equal Mime[:turbo_stream].to_s, response.media_type
  end

  test "should show diagnosis" do
    get diagnosis_url(@diagnosis)
    assert_response :success
  end

  test "should get edit" do
    get edit_diagnosis_url(@diagnosis)
    assert_response :success
  end

  test "should update diagnosis" do
    patch diagnosis_url(@diagnosis), params: { diagnosis: { name: "Updated Appendicitis" } }

    assert_redirected_to diagnosis_url(@diagnosis)
    @diagnosis.reload
    assert_equal "Updated Appendicitis", @diagnosis.name
  end

  test "should destroy diagnosis" do
    assert_difference("Diagnosis.count", -1) do
      delete diagnosis_url(diagnoses(:fracture))
    end

    assert_redirected_to diagnoses_url
  end

  test "should not destroy diagnosis in use" do
    assert_no_difference("Diagnosis.count") do
      delete diagnosis_url(@diagnosis)
    end

    assert_redirected_to diagnosis_url(@diagnosis)
  end
end
