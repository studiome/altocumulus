require "test_helper"

class CaseDatabaseEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @case_database = case_databases(:registry)
    @entry = case_database_entries(:one)
    @notes_field = case_database_fields(:notes)
    @number_field = case_database_fields(:ejection_fraction)
    @other_patient = patients(:two)
  end

  test "new searches patients by hospital id" do
    get new_case_database_entry_url(@case_database), params: { keyword: @other_patient.hospital_id }
    assert_response :success
    assert_match(@other_patient.name, @response.body)
  end

  test "new searches patients by name" do
    get new_case_database_entry_url(@case_database), params: { keyword: @other_patient.name }
    assert_response :success
    assert_match(@other_patient.hospital_id, @response.body)
  end

  test "new excludes patients already added to the database" do
    get new_case_database_entry_url(@case_database)
    assert_response :success
    assert_no_match(/#{Regexp.escape(@entry.patient.hospital_id)}/, @response.body)
  end

  test "any signed-in role can add a patient to the database" do
    assert_difference("CaseDatabaseEntry.count", 1) do
      post case_database_entries_url(@case_database), params: { patient_id: @other_patient.id }
    end
    assert_redirected_to case_database_url(@case_database)
  end

  test "adding the same patient twice redirects with an alert" do
    assert_no_difference("CaseDatabaseEntry.count") do
      post case_database_entries_url(@case_database), params: { patient_id: @entry.patient_id }
    end
    assert_redirected_to case_database_url(@case_database)
    assert_not_nil flash[:alert]
  end

  test "any signed-in role can update field values" do
    patch case_database_entry_url(@case_database, @entry), params: {
      case_database_entry: { field_values: { @notes_field.id.to_s => "Doing better" } }
    }
    assert_redirected_to case_database_url(@case_database)
    assert_equal "Doing better", @entry.reload.value_for(@notes_field)
  end

  test "an invalid number value renders 422" do
    patch case_database_entry_url(@case_database, @entry), params: {
      case_database_entry: { field_values: { @number_field.id.to_s => "not-a-number" } }
    }
    assert_response :unprocessable_entity
  end

  test "data manager can remove a patient entry" do
    sign_out
    sign_in_as(users(:data_manager))

    assert_difference("CaseDatabaseEntry.count", -1) do
      delete case_database_entry_url(@case_database, @entry)
    end
    assert_redirected_to case_database_url(@case_database)
  end

  test "member cannot remove a patient entry" do
    sign_out
    sign_in_as(users(:member))

    assert_no_difference("CaseDatabaseEntry.count") do
      delete case_database_entry_url(@case_database, @entry)
    end
    assert_redirected_to root_url
  end

  test "admin cannot remove a patient entry" do
    sign_out
    sign_in_as(users(:admin))

    assert_no_difference("CaseDatabaseEntry.count") do
      delete case_database_entry_url(@case_database, @entry)
    end
    assert_redirected_to root_url
  end
end
