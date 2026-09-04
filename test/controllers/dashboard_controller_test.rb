require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get dashboard_url
    assert_response :success
  end

  test "should get index scoped to a year" do
    get dashboard_url, params: { year: 2026 }
    assert_response :success
    assert_select "option[selected]", text: "2026"
  end

  test "should ignore a non-scalar year parameter" do
    get dashboard_url, params: { year: [ 2026 ] }
    assert_response :success
  end

  test "root still routes to patients#index" do
    get root_url
    assert_response :success
  end
end
