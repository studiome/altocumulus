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

  test "the form offers one radio per theme with the current one checked" do
    AppSetting.current.update!(title: "X", theme: "teal")

    get edit_admin_settings_url

    assert_select "fieldset input[type=radio][name='app_setting[theme]']", count: AppTheme::KEYS.size
    assert_select "input[type=radio][name='app_setting[theme]'][value=teal][checked]"
  end

  test "admin can change the theme" do
    patch admin_settings_url, params: { app_setting: { title: "Clinic", theme: "maroon" } }

    assert_redirected_to edit_admin_settings_url
    assert_equal "maroon", AppSetting.theme
  end

  test "an unknown theme is rejected" do
    patch admin_settings_url, params: { app_setting: { title: "Clinic", theme: "hotpink" } }

    assert_response :unprocessable_entity
    assert_equal "navy", AppSetting.theme
  end

  test "member cannot change the theme" do
    sign_out
    sign_in_as(users(:member))

    patch admin_settings_url, params: { app_setting: { title: "Clinic", theme: "green" } }

    assert_redirected_to root_url
    assert_equal "navy", AppSetting.theme
  end

  test "pages carry the default theme on the html element and in the theme-color meta" do
    get patients_url

    assert_select "html[data-app-theme=navy]"
    assert_select "meta[name=theme-color][content=?]", AppTheme.theme_color("navy")
  end

  test "pages carry the saved theme for every user" do
    AppSetting.current.update!(title: "X", theme: "green")
    sign_out
    sign_in_as(users(:member))

    get patients_url

    assert_select "html[data-app-theme=green]"
    assert_select "meta[name=theme-color][content=?]", AppTheme.theme_color("green")
  end
end
