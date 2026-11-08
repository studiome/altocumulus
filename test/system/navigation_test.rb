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

  test "the mobile hamburger menu is painted after scrolling far right and down on the operations calendar" do
    page.driver.browser.manage.window.resize_to(375, 812)
    visit operations_calendar_path(start: "2026-03-01", days: 30)
    page.execute_script("window.scrollTo(document.scrollingElement.scrollWidth, document.scrollingElement.scrollHeight)")
    find(".app-navbar [role='button'][aria-label]").click
    assert_selector ".app-navbar .dropdown-content a", text: "Patients", visible: true
    assert panel_painted?(I18n.t("nav.open_menu", locale: :en)), "hamburger panel was clipped"
  end

  test "the mobile hamburger menu is painted on the operations calendar" do
    page.driver.browser.manage.window.resize_to(375, 812)
    visit operations_calendar_path(start: "2026-03-01", days: 7)
    find(".app-navbar [role='button'][aria-label]").click
    assert_selector ".app-navbar .dropdown-content a", text: "Patients", visible: true
    assert panel_painted?(I18n.t("nav.open_menu", locale: :en)), "hamburger panel was clipped"
  end

  def navbar_pinned_state
    page.evaluate_script(<<~JS)
      (function () {
        var bar = document.querySelector('.app-navbar');
        var r = bar.getBoundingClientRect();
        var hit = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2);
        var edge = document.elementFromPoint(document.documentElement.clientWidth - 2, r.top + r.height / 2);
        var items = Array.from(bar.querySelectorAll('a, button, [role="button"]')).filter(function (el) { return el.offsetParent !== null; });
        return {
          left: r.left, top: r.top, width: r.width, inner: document.documentElement.clientWidth,
          covered: !(hit && bar.contains(hit)), edge_covered: !(edge && bar.contains(edge)),
          items_right: Math.max.apply(null, items.map(function (el) { return el.getBoundingClientRect().right; })),
          scrollY: window.scrollY, scrollX: window.scrollX
        };
      })()
    JS
  end

  [ [ 1400, 900 ], [ 375, 812 ] ].each do |width, height|
    test "on the operations calendar the navbar stays pinned to the top while scrolling at #{width}px" do
      page.driver.browser.manage.window.resize_to(width, height)
      visit operations_calendar_path(start: "2026-03-01", days: 30)

      page.execute_script("window.scrollTo(0, 600)")
      state = navbar_pinned_state
      assert_operator state["scrollY"], :>, 0, "the page should scroll vertically"
      assert_in_delta 0, state["top"], 1, "the navbar should stay at the viewport's top edge"
      assert_not state["covered"], "the navbar must not be covered by the ledger"

      page.execute_script("window.scrollTo(300, 600)")
      state = navbar_pinned_state
      assert_in_delta 0, state["left"], 1
      assert_in_delta 0, state["top"], 1
      assert_not state["covered"]

      # Far right and far bottom at once: pinned in both directions.
      page.execute_script("window.scrollTo(document.scrollingElement.scrollWidth, document.scrollingElement.scrollHeight)")
      state = navbar_pinned_state
      # Sideways scroll only exists when the ledger is wider than the window (not at 1400px with no cases).
      if page.evaluate_script("document.scrollingElement.scrollWidth > document.documentElement.clientWidth")
        assert_operator state["scrollX"], :>, 0, "the page should scroll sideways"
      end
      assert_operator state["scrollY"], :>, 0
      assert_in_delta 0, state["left"], 1
      assert_in_delta 0, state["top"], 1
      assert_in_delta state["inner"], state["width"], 1, "the navbar should be one visible viewport wide"
      assert_operator state["items_right"], :<=, state["inner"], "navbar controls must stay inside the viewport"
      assert_not state["covered"]
      assert_not state["edge_covered"], "the bar colour must reach the right edge of the viewport"
      page.save_screenshot(Rails.root.join("tmp/screenshots/navbar_pinned_far_#{width}.png"))
    end
  end

  test "the Masters menu is painted after scrolling down on the operations calendar" do
    page.driver.browser.manage.window.resize_to(1400, 900)
    visit operations_calendar_path(start: "2026-03-01", days: 30)
    page.execute_script("window.scrollTo(document.scrollingElement.scrollWidth, document.scrollingElement.scrollHeight)")
    find(".app-navbar [role='button']", text: "Masters").click
    assert_selector ".app-navbar .dropdown-content a", text: "Diagnoses", visible: true
    assert panel_painted?("Masters"), "Masters panel was clipped"
  end

  test "the Masters menu is painted on the patients page (control)" do
    page.driver.browser.manage.window.resize_to(1400, 900)
    visit patients_path
    find(".app-navbar [role='button']", text: "Masters").click
    assert_selector ".app-navbar .dropdown-content a", text: "Diagnoses", visible: true
    assert panel_painted?("Masters"), "Masters panel was clipped"
  end

  test "on a non-calendar page the navbar stays pinned to the top while scrolling" do
    page.driver.browser.manage.window.resize_to(1400, 300)
    visit patients_path
    page.execute_script("document.body.style.minHeight = '3000px'; window.scrollTo(0, 800)")
    state = navbar_pinned_state
    assert_operator state["scrollY"], :>, 0, "the page should scroll vertically"
    assert_in_delta 0, state["top"], 1, "the navbar should stay at the viewport's top edge"
    assert_not state["covered"], "the navbar must not be covered by the page"
    page.save_screenshot(Rails.root.join("tmp/screenshots/navbar_pinned_patients.png"))
  end

  test "the Masters menu is painted after scrolling down on a non-calendar page" do
    page.driver.browser.manage.window.resize_to(1400, 600)
    visit patients_path
    page.execute_script("document.body.style.minHeight = '3000px'; window.scrollTo(0, 800)")
    assert_in_delta 0, navbar_pinned_state["top"], 1, "the navbar should be pinned"
    find(".app-navbar [role='button']", text: "Masters").click
    assert_selector ".app-navbar .dropdown-content a", text: "Diagnoses", visible: true
    assert panel_painted?("Masters"), "Masters panel was clipped"
  end
end
