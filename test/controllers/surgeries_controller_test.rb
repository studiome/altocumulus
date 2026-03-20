require "test_helper"

class SurgeriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @surgery = surgeries(:one)
  end

  test "should get index" do
    get surgeries_url
    assert_response :success
  end

  test "should get new" do
    get new_surgery_url
    assert_response :success
  end

  test "should create surgery" do
    assert_difference("Surgery.count") do
      post surgeries_url, params: { surgery: {
        patient_id: patients(:one).id,
        surgery_date: "2026-03-03",
        laterality: "bilateral",
        procedure: surgery_procedures(:cholecystectomy).name,
        anesthesia_method: "General",
        duration_hours: 2.0
      } }
    end

    assert_redirected_to surgery_url(Surgery.last)
  end

  test "should show surgery" do
    get surgery_url(@surgery)
    assert_response :success
  end

  test "should get edit" do
    get edit_surgery_url(@surgery)
    assert_response :success
  end

  test "should update surgery" do
    patch surgery_url(@surgery), params: { surgery: {
      patient_id: @surgery.patient_id,
      surgery_date: @surgery.surgery_date,
      laterality: "none",
      procedure: surgery_procedures(:updated_procedure).name,
      anesthesia_method: @surgery.anesthesia_method,
      duration_hours: @surgery.duration_hours
    } }

    assert_redirected_to surgery_url(@surgery)
    @surgery.reload
    assert_equal surgery_procedures(:updated_procedure).name, @surgery.procedure
  end

  test "should destroy surgery" do
    assert_difference("Surgery.count", -1) do
      delete surgery_url(@surgery)
    end

    assert_redirected_to surgeries_url
  end
end
