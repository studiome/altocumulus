require "application_system_test_case"

# The ledger is wider than the window on real data: while the page scrolls
# sideways, the navbar and the full-width bands' contents stay in view.
class LedgerSidewaysScrollTest < ApplicationSystemTestCase
  DAY = Date.new(2026, 3, 3) # fixtures: an unassigned elective case -> a warning band

  BAND_SELECTORS = [
    "tbody#day-#{DAY.iso8601} tr.ledger-note-row td",
    "tbody#day-#{DAY.iso8601} tr.ledger-band-warning td"
  ].freeze

  def widen_ledger
    page.execute_script("document.querySelector('table.oc-ledger, .oc-ledger').style.minWidth = '3200px'")
    assert_operator page.evaluate_script("document.scrollingElement.scrollWidth"), :>, page.evaluate_script("document.documentElement.clientWidth") + 800
  end

  def navbar_rect
    page.evaluate_script(<<~JS)
      (function () {
        var bar = document.querySelector('.app-navbar');
        var r = bar.getBoundingClientRect();
        var items = Array.from(bar.querySelectorAll('a, button, [role="button"]')).filter(function (el) { return el.offsetParent !== null; });
        return { left: r.left, width: r.width, inner: document.documentElement.clientWidth, sx: window.scrollX,
                 items: Math.max.apply(null, items.map(function (el) { return el.getBoundingClientRect().right; })) };
      })()
    JS
  end

  # Left edge of the first text node's range of each band (what the eye sees).
  def band_lefts
    page.evaluate_script(<<~JS)
      (function () {
        var sels = #{BAND_SELECTORS.to_json};
        return sels.map(function (s) {
          var el = document.querySelector(s);
          if (!el) return null;
          var range = document.createRange();
          range.selectNodeContents(el);
          return range.getBoundingClientRect().left;
        });
      })()
    JS
  end

  [ [ 1400, 900 ], [ 1920, 1000 ] ].each do |width, height|
    test "at #{width}px the navbar and band contents stay in view while the ledger scrolls sideways" do
      Holiday.create!(date: DAY, holiday: false, note: "Staff meeting")
      page.driver.browser.manage.window.resize_to(width, height)
      visit operations_calendar_path(start: "2026-03-01", days: 7)
      widen_ledger
      assert_selector "tbody#day-#{DAY.iso8601} tr.ledger-band-warning"
      page.execute_script("window.scrollTo(0, 0)")
      before = band_lefts
      assert before.all?, "both bands should exist: #{before.inspect}"

      [ 600, 100_000 ].each do |x|
        page.execute_script("window.scrollTo(#{x}, 0)")
        nav = navbar_rect
        assert_operator nav["sx"], :>, 0
        assert_in_delta 0, nav["left"], 1, "navbar left at scrollX=#{nav['sx']}"
        assert_in_delta nav["inner"], nav["width"], 1, "navbar width at scrollX=#{nav['sx']}"
        assert_operator nav["items"], :<=, nav["inner"]
        band_lefts.each_with_index do |left, i|
          assert_in_delta before[i], left, 1, "band #{i} content scrolled away at scrollX=#{nav['sx']}"
        end
      end
      page.save_screenshot(Rails.root.join("tmp/screenshots/ledger_sideways_#{width}.png"))
    end
  end

  test "the navbar stays pinned after Turbo navigation into the calendar and a window resize" do
    page.driver.browser.manage.window.resize_to(1400, 900)
    visit patients_path
    first("a", text: /Calendar/).click
    assert_selector ".oc-ledger"
    widen_ledger
    page.execute_script("window.scrollTo(600, 0)")
    nav = navbar_rect
    assert_in_delta 0, nav["left"], 1
    assert_in_delta nav["inner"], nav["width"], 1

    page.driver.browser.manage.window.resize_to(1700, 900)
    assert_equal 1700 - (1400 - nav["inner"]), page.evaluate_script("document.documentElement.clientWidth")
    page.execute_script("window.scrollTo(600, 0)")
    nav = navbar_rect
    assert_in_delta 0, nav["left"], 1
    assert_in_delta nav["inner"], nav["width"], 1
  end

  # WebKit (Safari) does not always grow the body to the table, so a sticky
  # navbar has no room to stick: on the calendar it is fixed instead, with the
  # body's top padding as its spacer.
  test "on the calendar the navbar is fixed to the viewport and the page content starts below it" do
    page.driver.browser.manage.window.resize_to(1400, 900)
    visit operations_calendar_path(start: "2026-03-01", days: 7)
    widen_ledger
    state = page.evaluate_script(<<~JS)
      (function () {
        var bar = document.querySelector('.app-navbar');
        var main = document.querySelector('.app-main');
        return { position: getComputedStyle(bar).position, bottom: bar.getBoundingClientRect().bottom,
                 main_top: main.getBoundingClientRect().top };
      })()
    JS
    assert_equal "fixed", state["position"]
    assert_operator state["main_top"], :>=, state["bottom"] - 1, "the page content must not sit under the navbar"
    page.execute_script("window.scrollTo(600, 300)")
    nav = navbar_rect
    assert_in_delta 0, nav["left"], 1
    assert_in_delta nav["inner"], nav["width"], 1
  end
end
