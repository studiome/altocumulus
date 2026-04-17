require "test_helper"

class DiagnosesControllerTest < ActionDispatch::IntegrationTest
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

  test "should create diagnosis via turbo stream" do
    assert_difference("Diagnosis.count") do
      post diagnoses_url(format: :turbo_stream), params: { diagnosis: { name: "Migraine with aura" } }
    end

    assert_response :success
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
