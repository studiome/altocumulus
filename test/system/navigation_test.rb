require "application_system_test_case"

class NavigationTest < ApplicationSystemTestCase
  test "the header navigation does not overflow the viewport at a 375px mobile width" do
    page.driver.browser.manage.window.resize_to(375, 812)
    # Not the root (the operations calendar): its ledger now scrolls the page sideways on purpose.
    visit patients_path

    overflow = page.evaluate_script(
      "document.documentElement.scrollWidth > document.documentElement.clientWidth"
    )
    assert_not overflow, "the header caused horizontal overflow at a 375px viewport width"
  end

  test "on the operations calendar at 375px the navbar stays one viewport wide and in view while the ledger scrolls" do
    page.driver.browser.manage.window.resize_to(375, 812)
    visit operations_calendar_path(start: "2026-03-01", days: 7)
    page.execute_script("window.scrollTo(300, 0)")

    inner = page.evaluate_script("window.innerWidth")
    scroll_width = page.evaluate_script("document.scrollingElement.scrollWidth")
    nav = page.evaluate_script(<<~JS)
      (function () {
        var bar = document.querySelector('.app-navbar');
        var rect = bar.getBoundingClientRect();
        var items = Array.from(bar.querySelectorAll('a, button')).filter(function (el) { return el.offsetParent !== null; });
        return { left: rect.left, width: rect.width, items: Math.max.apply(null, items.map(function (el) { return el.getBoundingClientRect().right; })) };
      })()
    JS
    assert_operator scroll_width, :>, inner, "the ledger should scroll the page sideways"
    assert_in_delta 0, nav["left"], 1, "the navbar should stay at the viewport's left edge"
    assert_operator nav["width"], :<=, inner + 1, "the navbar content area must not stretch to the table width"
    assert_operator nav["items"], :<=, inner, "navbar controls must stay inside the viewport"
  end
end
