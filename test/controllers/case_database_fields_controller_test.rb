require "test_helper"

class CaseDatabaseFieldsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @case_database = case_databases(:registry)
    @field = case_database_fields(:notes)
  end

  test "data manager can get the new field form" do
    sign_out
    sign_in_as(users(:data_manager))

    get new_case_database_field_url(@case_database)
    assert_response :success
  end

  test "member cannot get the new field form" do
    sign_out
    sign_in_as(users(:member))

    get new_case_database_field_url(@case_database)
    assert_redirected_to root_url
  end

  test "data manager can create a field" do
    sign_out
    sign_in_as(users(:data_manager))

    assert_difference("CaseDatabaseField.count", 1) do
      post case_database_fields_url(@case_database), params: { case_database_field: { label: "Grade", field_type: "text" } }
    end
    assert_redirected_to case_database_url(@case_database)
  end

  test "member cannot create a field" do
    sign_out
    sign_in_as(users(:member))

    assert_no_difference("CaseDatabaseField.count") do
      post case_database_fields_url(@case_database), params: { case_database_field: { label: "Grade", field_type: "text" } }
    end
    assert_redirected_to root_url
  end

  test "admin cannot create a field" do
    sign_out
    sign_in_as(users(:admin))

    assert_no_difference("CaseDatabaseField.count") do
      post case_database_fields_url(@case_database), params: { case_database_field: { label: "Grade", field_type: "text" } }
    end
    assert_redirected_to root_url
  end

  test "data manager can update a field" do
    sign_out
    sign_in_as(users(:data_manager))

    patch case_database_field_url(@case_database, @field), params: { case_database_field: { label: "Clinical Notes" } }
    assert_redirected_to case_database_url(@case_database)
    assert_equal "Clinical Notes", @field.reload.label
  end

  test "member cannot update a field" do
    sign_out
    sign_in_as(users(:member))

    patch case_database_field_url(@case_database, @field), params: { case_database_field: { label: "Clinical Notes" } }
    assert_redirected_to root_url
    assert_not_equal "Clinical Notes", @field.reload.label
  end

  test "data manager can delete a field" do
    sign_out
    sign_in_as(users(:data_manager))

    assert_difference("CaseDatabaseField.count", -1) do
      delete case_database_field_url(@case_database, @field)
    end
    assert_redirected_to case_database_url(@case_database)
  end

  test "member cannot delete a field" do
    sign_out
    sign_in_as(users(:member))

    assert_no_difference("CaseDatabaseField.count") do
      delete case_database_field_url(@case_database, @field)
    end
    assert_redirected_to root_url
  end
end
