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
    patch account_url, params: { user: { name: "Updated Name", login_id: @admin.login_id } }
    assert_redirected_to account_url
    assert_equal "Updated Name", @admin.reload.name
  end

  test "changing password requires the current password" do
    patch account_url, params: { user: { name: @admin.name, login_id: @admin.login_id, current_password: "wrong-password", password: "newpassword", password_confirmation: "newpassword" } }
    assert_response :unprocessable_entity
    assert @admin.reload.authenticate("password")
  end

  test "changing password requires confirmation" do
    patch account_url, params: { user: { name: @admin.name, login_id: @admin.login_id, current_password: "password", password: "newpassword", password_confirmation: "" } }
    assert_response :unprocessable_entity
    assert @admin.reload.authenticate("password")
  end

  test "changes password with correct current password and matching confirmation" do
    patch account_url, params: { user: { name: @admin.name, login_id: @admin.login_id, current_password: "password", password: "newpassword", password_confirmation: "newpassword" } }
    assert_redirected_to account_url
    assert @admin.reload.authenticate("newpassword")
  end

  test "account page offers the language choice with the current language marked" do
    get account_url
    assert_select "main form[action=?]", locale_path(locale: "ja")
    assert_select "main form[action=?] button.font-bold", locale_path(locale: "en")
  end

  test "changing language on the account page persists it and returns to the account page" do
    patch locale_path(locale: "ja"), headers: { "HTTP_REFERER" => account_url }
    assert_redirected_to account_url
    assert_equal "ja", @admin.reload.locale
    follow_redirect!
    assert_select "h1", "アカウント"
  end

  test "language switcher is no longer in the signed-in navigation" do
    get patients_url
    assert_response :success
    assert_select "header form[action=?]", locale_path(locale: "ja"), count: 0
    assert_select "header form[action=?]", locale_path(locale: "en"), count: 0
  end
end
