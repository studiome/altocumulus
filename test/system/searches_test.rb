require "application_system_test_case"

class SearchesSystemTest < ApplicationSystemTestCase
  setup { sign_in_as(users(:admin)) }

  test "print layout lets the search panel break across pages" do
    visit search_path(keyword: "John")
    assert_selector "#search-panel"
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    begin
      break_inside = page.evaluate_script("getComputedStyle(document.getElementById('search-panel')).breakInside")
      assert_not_equal "avoid", break_inside
    ensure
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "")
    end
  end
end
