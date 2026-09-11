require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @member = users(:member)
  end

  test "admin can view the user list" do
    get admin_users_url
    assert_response :success
    assert_select "td", text: @member.login_id
  end

  test "member cannot view the user list" do
    sign_out
    sign_in_as(@member)

    get admin_users_url
    assert_redirected_to root_url
  end

  test "member cannot reach the new user form" do
    sign_out
    sign_in_as(@member)

    get new_admin_user_url
    assert_redirected_to root_url
  end

  test "admin can create a new user" do
    assert_difference("User.count", 1) do
      post admin_users_url, params: { user: { name: "New User", login_id: "created@example.com", password: "password", password_confirmation: "password", role: "user", active: true } }
    end
    assert_redirected_to admin_users_url
  end

  test "admin can update a user's role and active flag" do
    patch admin_user_url(@member), params: { user: { name: @member.name, login_id: @member.login_id, role: "admin", active: true } }
    assert_redirected_to admin_users_url
    assert @member.reload.admin?
  end

  test "admin cannot deactivate the last active admin" do
    User.where(role: "admin").where.not(id: @admin.id).update_all(active: false)

    patch admin_user_url(@admin), params: { user: { name: @admin.name, login_id: @admin.login_id, role: @admin.role, active: false } }
    assert_response :unprocessable_entity
    assert @admin.reload.active?
  end

  test "admin can reset another user's password" do
    original_digest = @member.password_digest

    patch reset_password_admin_user_url(@member)
    assert_redirected_to admin_users_url
    assert_not_equal original_digest, @member.reload.password_digest
  end

  test "member cannot reset a password" do
    sign_out
    sign_in_as(@member)

    patch reset_password_admin_user_url(@admin)
    assert_redirected_to root_url
  end
end
