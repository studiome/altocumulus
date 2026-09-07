require "application_system_test_case"

class NavigationTest < ApplicationSystemTestCase
  test "the header navigation does not overflow the viewport at a 375px mobile width" do
    page.driver.browser.manage.window.resize_to(375, 812)
    visit root_path

    overflow = page.evaluate_script(
      "document.documentElement.scrollWidth > document.documentElement.clientWidth"
    )
    assert_not overflow, "the header caused horizontal overflow at a 375px viewport width"
  end
end
