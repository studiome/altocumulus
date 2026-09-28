require "test_helper"

class CaseDatabasesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @case_database = case_databases(:registry)
  end

  test "any signed-in role can view the index" do
    [ :admin, :member, :data_manager ].each do |fixture|
      sign_out
      sign_in_as(users(fixture))

      get case_databases_url
      assert_response :success
      assert_match(@case_database.name, @response.body)
    end
  end

  test "any signed-in role can view a database's show page" do
    [ :admin, :member, :data_manager ].each do |fixture|
      sign_out
      sign_in_as(users(fixture))

      get case_database_url(@case_database)
      assert_response :success
    end
  end

  test "show exports the database as CSV" do
    get case_database_url(@case_database, format: :csv)
    assert_response :success
    assert_equal "text/csv", @response.media_type
    assert_equal "utf-8", @response.charset
    assert_match(/Hospital ID/, @response.body)
  end

  test "data manager can get the new form" do
    sign_out
    sign_in_as(users(:data_manager))

    get new_case_database_url
    assert_response :success
  end

  test "member cannot get the new form" do
    sign_out
    sign_in_as(users(:member))

    get new_case_database_url
    assert_redirected_to root_url
  end

  test "admin cannot get the new form" do
    sign_out
    sign_in_as(users(:admin))

    get new_case_database_url
    assert_redirected_to root_url
  end

  test "a user holding both admin and data_manager roles can create a case database" do
    sign_out
    sign_in_as(users(:admin_data_manager))

    assert_difference("CaseDatabase.count", 1) do
      post case_databases_url, params: { case_database: { name: "Admin DM Registry", description: "desc" } }
    end
    assert_redirected_to case_database_url(CaseDatabase.last)
  end

  test "data manager can create a case database" do
    sign_out
    sign_in_as(users(:data_manager))

    assert_difference("CaseDatabase.count", 1) do
      post case_databases_url, params: { case_database: { name: "New Registry", description: "desc" } }
    end
    assert_redirected_to case_database_url(CaseDatabase.last)
  end

  test "member cannot create a case database" do
    sign_out
    sign_in_as(users(:member))

    assert_no_difference("CaseDatabase.count") do
      post case_databases_url, params: { case_database: { name: "New Registry" } }
    end
    assert_redirected_to root_url
  end

  test "admin cannot create a case database" do
    sign_out
    sign_in_as(users(:admin))

    assert_no_difference("CaseDatabase.count") do
      post case_databases_url, params: { case_database: { name: "New Registry" } }
    end
    assert_redirected_to root_url
  end

  test "data manager can update a case database" do
    sign_out
    sign_in_as(users(:data_manager))

    patch case_database_url(@case_database), params: { case_database: { name: "Renamed Registry" } }
    assert_redirected_to case_database_url(@case_database)
    assert_equal "Renamed Registry", @case_database.reload.name
  end

  test "member cannot update a case database" do
    sign_out
    sign_in_as(users(:member))

    patch case_database_url(@case_database), params: { case_database: { name: "Renamed Registry" } }
    assert_redirected_to root_url
    assert_not_equal "Renamed Registry", @case_database.reload.name
  end

  test "data manager can delete a case database" do
    sign_out
    sign_in_as(users(:data_manager))

    assert_difference("CaseDatabase.count", -1) do
      delete case_database_url(@case_database)
    end
    assert_redirected_to case_databases_url
  end

  test "member cannot delete a case database" do
    sign_out
    sign_in_as(users(:member))

    assert_no_difference("CaseDatabase.count") do
      delete case_database_url(@case_database)
    end
    assert_redirected_to root_url
  end

  test "admin cannot delete a case database" do
    sign_out
    sign_in_as(users(:admin))

    assert_no_difference("CaseDatabase.count") do
      delete case_database_url(@case_database)
    end
    assert_redirected_to root_url
  end
end
