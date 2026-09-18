require "test_helper"

class Admin::SettingsControllerTest < ActionDispatch::IntegrationTest
  test "admin can open the settings form prefilled with the current title" do
    get edit_admin_settings_url

    assert_response :success
    assert_select "input[name='app_setting[title]'][value=?]", AppSetting.title
  end

  test "member cannot open the settings form" do
    sign_out
    sign_in_as(users(:member))

    get edit_admin_settings_url
    assert_redirected_to root_url
  end

  test "admin can change the application title" do
    patch admin_settings_url, params: { app_setting: { title: "Kohoku Clinic" } }

    assert_redirected_to edit_admin_settings_url
    assert_equal "Kohoku Clinic", AppSetting.title
  end

  test "the new title shows up in the navigation bar" do
    patch admin_settings_url, params: { app_setting: { title: "Kohoku Clinic" } }

    get root_url

    assert_response :success
    assert_select "header a", text: "Kohoku Clinic"
  end

  test "a blank title is rejected" do
    patch admin_settings_url, params: { app_setting: { title: "" } }

    assert_response :unprocessable_entity
  end

  test "member cannot change the application title" do
    sign_out
    sign_in_as(users(:member))

    patch admin_settings_url, params: { app_setting: { title: "Hijacked" } }

    assert_redirected_to root_url
    assert_not_equal "Hijacked", AppSetting.title
  end
end
