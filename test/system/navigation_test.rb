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
        var items = Array.from(bar.querySelectorAll('a, button, [role="button"]')).filter(function (el) { return el.offsetParent !== null; });
        return { left: rect.left, width: rect.width, items: Math.max.apply(null, items.map(function (el) { return el.getBoundingClientRect().right; })) };
      })()
    JS
    assert_operator scroll_width, :>, inner, "the ledger should scroll the page sideways"
    assert_in_delta 0, nav["left"], 1, "the navbar should stay at the viewport's left edge"
    assert_operator nav["width"], :<=, inner + 1, "the navbar content area must not stretch to the table width"
    assert_operator nav["items"], :<=, inner, "navbar controls must stay inside the viewport"
  end

  # A dropdown panel that is clipped (e.g. by a clip-path on the navbar) is
  # still "displayed" for Capybara, so ask the browser what is really painted
  # at the panel's centre. The trigger is found by its text or aria-label.
  def panel_painted?(label)
    page.evaluate_script(<<~JS)
      (function () {
        var label = #{label.to_json};
        var trigger = Array.from(document.querySelectorAll('.app-navbar .dropdown > [role=button]')).find(function (el) {
          return el.offsetParent !== null && (el.textContent.trim() === label || el.getAttribute('aria-label') === label);
        });
        var panel = trigger.parentElement.querySelector('.dropdown-content');
        var r = panel.getBoundingClientRect();
        if (r.width === 0 || r.height === 0) return false;
        var hit = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2);
        return !!hit && panel.contains(hit);
      })()
    JS
  end

  test "the Masters menu is painted on the operations calendar at desktop width" do
    page.driver.browser.manage.window.resize_to(1400, 900)
    visit operations_calendar_path(start: "2026-03-01", days: 7)
    find(".app-navbar [role='button']", text: "Masters").click
    assert_selector ".app-navbar .dropdown-content a", text: "Diagnoses", visible: true
    assert panel_painted?("Masters"), "Masters panel was clipped"
  end

  test "the mobile hamburger menu is painted on the operations calendar" do
    page.driver.browser.manage.window.resize_to(375, 812)
    visit operations_calendar_path(start: "2026-03-01", days: 7)
    find(".app-navbar [role='button'][aria-label]").click
    assert_selector ".app-navbar .dropdown-content a", text: "Patients", visible: true
    assert panel_painted?(I18n.t("nav.open_menu", locale: :en)), "hamburger panel was clipped"
  end

  test "the Masters menu is painted on the patients page (control)" do
    page.driver.browser.manage.window.resize_to(1400, 900)
    visit patients_path
    find(".app-navbar [role='button']", text: "Masters").click
    assert_selector ".app-navbar .dropdown-content a", text: "Diagnoses", visible: true
    assert panel_painted?("Masters"), "Masters panel was clipped"
  end
end
