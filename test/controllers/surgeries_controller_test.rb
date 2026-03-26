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
        anesthesia_method: "General",
        duration_hours: 2.0,
        surgery_procedure_selections_attributes: {
          "0" => { surgery_procedure_id: surgery_procedures(:cholecystectomy).id, laterality: "bilateral" },
          "1" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "left" }
        }
      } }
    end

    assert_redirected_to surgery_url(Surgery.last)
    assert_equal [ "Cholecystectomy", "Appendectomy" ], Surgery.last.procedure_names
    assert_equal [ "bilateral", "left" ], Surgery.last.surgery_procedure_selections.order(:id).pluck(:laterality)
    assert_equal "Bilateral Cholecystectomy、Left Appendectomy", Surgery.last.display_procedure_name
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
      anesthesia_method: @surgery.anesthesia_method,
      duration_hours: @surgery.duration_hours,
      surgery_procedure_selections_attributes: {
        "0" => { id: surgery_procedure_selections(:one_appendectomy).id, surgery_procedure_id: surgery_procedures(:updated_procedure).id, laterality: "left" },
        "1" => { id: surgery_procedure_selections(:one_knee_arthroscopy).id, surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      }
    } }

    assert_redirected_to surgery_url(@surgery)
    @surgery.reload
    assert_equal [ "Updated Procedure", "Appendectomy" ], @surgery.procedure_names
    assert_equal [ "left", "right" ], @surgery.surgery_procedure_selections.order(:id).pluck(:laterality)
    assert_equal "Left Updated Procedure、Right Appendectomy", @surgery.display_procedure_name
  end

  test "should destroy surgery" do
    assert_difference("Surgery.count", -1) do
      delete surgery_url(@surgery)
    end

    assert_redirected_to surgeries_url
  end
end
