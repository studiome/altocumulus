require "application_system_test_case"

class AppThemeTest < ApplicationSystemTestCase
  test "the navbar colour follows the theme an administrator saved" do
    visit patients_path
    navy = page.evaluate_script("getComputedStyle(document.querySelector('.app-navbar')).backgroundColor")

    AppSetting.current.update!(title: AppSetting.title, theme: "green")
    visit patients_path

    assert_selector "html[data-app-theme=green]", visible: :all
    green = page.evaluate_script("getComputedStyle(document.querySelector('.app-navbar')).backgroundColor")
    assert_not_equal navy, green
  end

  test "saving a theme recolours the page through Turbo without a reload and keeps it across visits" do
    visit edit_admin_settings_path
    navy = page.evaluate_script("getComputedStyle(document.querySelector('.app-navbar')).backgroundColor")

    choose "Green", allow_label_click: true
    click_button "Save Settings"
    assert_text "Settings were successfully updated."

    assert_equal "green", page.evaluate_script("document.documentElement.dataset.appTheme")
    green = page.evaluate_script("getComputedStyle(document.querySelector('.app-navbar')).backgroundColor")
    assert_not_equal navy, green

    click_link "Patients", match: :first
    assert_current_path patients_path
    assert_equal "green", page.evaluate_script("document.documentElement.dataset.appTheme")
    assert_equal green, page.evaluate_script("getComputedStyle(document.querySelector('.app-navbar')).backgroundColor")
  end
end
