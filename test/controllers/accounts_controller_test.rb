require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
  end

  test "shows the current account" do
    get account_url
    assert_response :success
  end

  test "updates name and email without touching password" do
    patch account_url, params: { user: { name: "Updated Name", email: @admin.email } }
    assert_redirected_to account_url
    assert_equal "Updated Name", @admin.reload.name
  end

  test "changing password requires the current password" do
    patch account_url, params: { user: { name: @admin.name, email: @admin.email, current_password: "wrong-password", password: "newpassword", password_confirmation: "newpassword" } }
    assert_response :unprocessable_entity
    assert @admin.reload.authenticate("password")
  end

  test "changing password requires confirmation" do
    patch account_url, params: { user: { name: @admin.name, email: @admin.email, current_password: "password", password: "newpassword", password_confirmation: "" } }
    assert_response :unprocessable_entity
    assert @admin.reload.authenticate("password")
  end

  test "changes password with correct current password and matching confirmation" do
    patch account_url, params: { user: { name: @admin.name, email: @admin.email, current_password: "password", password: "newpassword", password_confirmation: "newpassword" } }
    assert_redirected_to account_url
    assert @admin.reload.authenticate("newpassword")
  end
end
