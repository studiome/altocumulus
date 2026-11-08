require "application_system_test_case"

class OperationsCalendarSystemTest < ApplicationSystemTestCase
  DAY = Date.new(2026, 3, 4) # a Wednesday with two weekday slots and no surgeries

  test "switching tabs keeps the range and shows the examination ledger" do
    hospitalizations(:two).update_columns(purpose: "examination", scheduled_procedure_date: Date.new(2026, 3, 5),
                                          scheduled_admission_date: Date.new(2026, 3, 5), admission_date: nil, discharge_date: nil)
    visit operations_calendar_path(start: "2026-03-01", days: 7)

    assert_selector "[role=tab][aria-selected=true]", text: "Surgery"
    assert_selector ".oc-legend"
    click_on "Examination admission"

    assert_selector "[role=tab][aria-selected=true]", text: "Examination admission"
    assert_current_path(/view=examination/)
    assert_current_path(/start=2026-03-01/)
    assert_selector ".oc-day", count: 7
    within("tbody#day-2026-03-05") { assert_text "Jane Smith" }
    assert_no_selector ".oc-legend"
    assert_text "No examination admissions scheduled", minimum: 1
  end

  test "arrow keys move focus between tabs without navigating" do
    visit operations_calendar_path(start: "2026-03-01", days: 7)
    page.execute_script("document.getElementById('oc-tab-surgery').focus()")

    find("#oc-tab-surgery").send_keys(:arrow_right)

    assert_equal "oc-tab-examination", page.evaluate_script("document.activeElement.id")
    assert_equal "0", find("#oc-tab-examination")[:tabindex]
    assert_equal "-1", find("#oc-tab-surgery")[:tabindex]
    assert_selector "[role=tab][aria-selected=true]", text: "Surgery"
  end

  test "the admission tab lists a surgery and an examination admission on the same day with the count" do
    day = Date.new(2026, 3, 5)
    hospitalizations(:one).update_columns(purpose: "surgery", scheduled_admission_date: day, admission_date: nil, discharge_date: nil)
    hospitalizations(:two).update_columns(purpose: "examination", scheduled_procedure_date: day + 3, scheduled_admission_date: day, admission_date: nil, discharge_date: nil)
    visit operations_calendar_path(start: "2026-03-01", days: 7)
    click_on "Admissions"

    assert_selector "[role=tab][aria-selected=true]", text: "Admissions"
    assert_current_path(/view=admission/)
    within("tbody#day-#{day.iso8601}") do
      assert_selector "tr.oc-admission", count: 2
      assert_text(/Admissions:\s*2/)
    end
  end

  test "an admin edits a day's note in place and the day re-renders without a page load" do
    visit operations_calendar_path(start: "2026-03-01", days: 7)
    page.execute_script("window.__stays = true")

    find("tbody#day-#{DAY.iso8601}").hover
    within("tbody#day-#{DAY.iso8601}") { click_on "Add note" }
    within("turbo-frame#day-note-#{DAY.iso8601}") do
      fill_in "Note", with: "Staff meeting"
      fill_in "Slots", with: "1"
      click_on "Save"
    end

    within("tbody#day-#{DAY.iso8601}") do
      assert_text "Staff meeting"
      assert_text "Slots 1"
      assert_text "(changed)"
    end
    assert page.evaluate_script("window.__stays"), "the page was reloaded"
    assert_equal "Staff meeting", Holiday.find_by!(date: DAY).note

    find("tbody#day-#{DAY.iso8601}").hover
    within("tbody#day-#{DAY.iso8601}") { click_on "Edit" }
    within("turbo-frame#day-note-#{DAY.iso8601}") do
      fill_in "Note", with: ""
      click_on "Save"
      assert_text "must have"
    end
    within("turbo-frame#day-note-#{DAY.iso8601}") { accept_confirm { click_on "Delete this day's note" } }

    within("tbody#day-#{DAY.iso8601}") { assert_no_text "Staff meeting" }
    assert_nil Holiday.find_by(date: DAY)
  end

  test "an admin sets a day's special slot lanes in place and the day shows the changed marker" do
    SpecialSlotRule.create!(resource: surgery_locations(:cath_lab), day_of_week: DAY.wday, slot_count: 1)
    visit operations_calendar_path(start: "2026-03-01", days: 7)
    page.execute_script("window.__stays = true")

    find("tbody#day-#{DAY.iso8601}").hover
    within("tbody#day-#{DAY.iso8601}") { click_on "Edit special slots" }
    within("turbo-frame#day-special-slots-#{DAY.iso8601}") do
      fill_in "Cath Lab", with: "3"
      click_on "Save"
    end

    within("tbody#day-#{DAY.iso8601}") { assert_text "Cath Lab 0/3 lanes (0/540 min) (changed)" }
    assert page.evaluate_script("window.__stays"), "the page was reloaded"
    assert_equal 3, SpecialSlotDayOverride.find_by!(resource: surgery_locations(:cath_lab), date: DAY).slot_count
  end

  test "the edit link is reachable from the keyboard" do
    Holiday.create!(date: DAY, holiday: false, note: "Existing")
    visit operations_calendar_path(start: DAY.iso8601, days: 1)
    link = find("tbody#day-#{DAY.iso8601} a", exact_text: "Edit", visible: :all)
    page.execute_script("arguments[0].focus()", link)
    opacity = nil
    40.times do # the fade takes a moment
      opacity = page.evaluate_script("getComputedStyle(document.activeElement).opacity")
      break if opacity == "1"
      sleep 0.05
    end
    assert_equal "1", opacity
  end

  test "a non-admin sees the notes but no edit controls" do
    Holiday.create!(date: DAY, holiday: false, note: "Existing")
    users(:admin).user_roles.where(role: "admin").delete_all
    visit operations_calendar_path(start: "2026-03-03", days: 3)

    assert_text "Existing"
    assert_no_link "Edit", exact: true, visible: :all
    assert_no_link "Add note", visible: :all
  end

  test "print layout lets the ledger panel break across pages and keeps badges on one line" do
    visit operations_calendar_path(start: "2026-03-01", days: 7)
    assert_selector "table.oc-ledger .badge.ledger-badge", minimum: 1
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    # A printed page is far narrower than the test window; the badge column is
    # only crushed when the table has to share a narrow width.
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 720, height: 1000, deviceScaleFactor: 1, mobile: false)
    begin
      break_inside = page.evaluate_script(
        "getComputedStyle(document.querySelector('table.oc-ledger').closest('.app-panel')).breakInside")
      assert_not_equal "avoid", break_inside

      multi_line = page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll('.oc-ledger .badge.ledger-badge')).filter(function (badge) {
          var text = badge.textContent.trim();
          if (text === "" || /\\s/.test(text)) return false;
          var range = document.createRange();
          range.selectNodeContents(badge);
          return range.getClientRects().length > 1;
        }).map(function (badge) { return badge.textContent.trim(); })
      JS
      assert_empty multi_line, "single-word badges wrapped inside the word"

      overflow = page.evaluate_script(
        "document.querySelector('table.oc-ledger').getBoundingClientRect().right - document.documentElement.clientWidth")
      assert_operator overflow, :<=, 1, "the ledger table runs past the printable width"
    ensure
      page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "")
    end
  end

  test "a narrow window scrolls the ledger with the page, not an inner box" do
    page.driver.browser.manage.window.resize_to(800, 1000)
    visit operations_calendar_path(start: "2026-03-01", days: 7)
    assert_selector "table.oc-ledger td.ledger-day", minimum: 1

    clipping = page.evaluate_script(<<~JS)
      (function () {
        var found = [];
        for (var el = document.querySelector('table.oc-ledger').parentElement; el; el = el.parentElement) {
          var x = getComputedStyle(el).overflowX;
          if (x !== "visible") found.push(el.tagName + "." + el.className + ":" + x);
        }
        return found;
      })()
    JS
    assert_empty clipping, "ancestors of the ledger must not be scroll containers"

    assert page.evaluate_script("document.scrollingElement.scrollWidth > document.scrollingElement.clientWidth"),
           "the page itself should scroll horizontally"

    page.execute_script("window.scrollTo(200, 0)")
    assert_operator page.evaluate_script("window.scrollX"), :>, 0
    left = page.evaluate_script("document.querySelector('td.ledger-day').getBoundingClientRect().left")
    assert_in_delta 0, left, 1, "the day column should stay stuck to the viewport's left edge"

    inner = page.evaluate_script("document.documentElement.clientWidth")
    assert_operator page.evaluate_script("document.scrollingElement.scrollWidth"), :>, inner
    assert_pinned_parts_in_view
  end

  test "pinned parts stay inside the visible width when the page has a classic scrollbar" do
    page.driver.browser.manage.window.resize_to(800, 1000)
    visit operations_calendar_path(start: "2026-03-01", days: 7)
    assert_selector "table.oc-ledger td.ledger-day", minimum: 1
    assert_operator page.evaluate_script("window.innerWidth - document.documentElement.clientWidth"), :>, 0, "the system test browser should use classic scrollbars"

    assert_pinned_parts_in_view
  end

  private

  # At a middle and at the maximum scroll position (where a pinned box that is
  # as wide as 100vw is pushed left by the scrollbar width, and at a middle one
  # runs under the scrollbar), the navbar, header, tabs and legend must lie
  # inside the visible width: left >= 0 (the cards keep their gutter) and
  # right <= clientWidth.
  def assert_pinned_parts_in_view
    visible = page.evaluate_script("document.documentElement.clientWidth")
    maximum = page.evaluate_script("document.scrollingElement.scrollWidth") - visible
    assert_operator maximum, :>, 100, "the page should scroll sideways"

    [ 100, maximum ].each do |x|
      page.execute_script("window.scrollTo(#{x}, 0)")
      assert_equal x, page.evaluate_script("Math.round(window.scrollX)")
      [ ".app-navbar", ".app-page-header", "[role=tablist]", ".oc-legend" ].each do |selector|
        left, right = page.evaluate_script("(function(){var r=document.querySelector('#{selector}').getBoundingClientRect();return [r.left,r.right]})()")
        assert_operator left, :>=, -0.5, "#{selector} is cut off on the left at scrollX=#{x}"
        assert_operator right, :<=, visible + 0.5, "#{selector} runs under the scrollbar at scrollX=#{x}"
      end
    end
  end

  test "long diagnosis and procedure names wrap inside a narrow column and the type column stays narrow" do
    long = "Very long diagnosis name that keeps going and going well past any reasonable column width"
    Diagnosis.find_each { |record| record.update_columns(name: "#{long} #{record.id}") }
    SurgeryProcedure.find_each { |record| record.update_columns(name: "#{long} procedure #{record.id}") }
    visit operations_calendar_path(start: "2026-03-01", days: 7)

    widths = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(".oc-ledger thead th")).map(th => [th.textContent.trim(), th.getBoundingClientRect().width])
    JS
    diagnosis = widths.find { |text, _| text.include?("Diagnosis") }.last
    type = widths.find { |text, _| text.start_with?("Type") }.last
    assert_operator diagnosis, :<=, 210, "diagnosis column is #{diagnosis}px"
    assert_operator type, :<=, 110, "type column is #{type}px"

    lines = page.evaluate_script(<<~JS)
      (() => {
        const row = document.querySelector("tbody#day-2026-03-01 tr.oc-surgery");
        const cell = row.querySelector("td.ledger-diagnosis_procedure, td:nth-child(3)");
        return [cell.getBoundingClientRect().height, parseFloat(getComputedStyle(cell).lineHeight) || 16];
      })()
    JS
    assert_operator lines.first, :>, lines.last * 3, "long names should wrap onto several lines"
  end

  test "header, tabs, legend and the table panel add no box of their own on the calendar page" do
    visit operations_calendar_path(start: "2026-03-01", days: 7)

    boxes = page.evaluate_script(<<~JS)
      (() => {
        const body = getComputedStyle(document.body).backgroundColor;
        const targets = {
          header: document.querySelector("body.oc-page .app-page-header"),
          tablist: document.querySelector("body.oc-page [role='tablist']"),
          legend: document.querySelector("body.oc-page .oc-legend"),
          panel: document.querySelector("table.oc-ledger").closest(".app-panel")
        };
        const out = { body: body };
        for (const [name, el] of Object.entries(targets)) {
          const cs = getComputedStyle(el);
          out[name] = { bg: cs.backgroundColor, shadow: cs.boxShadow,
            borders: [cs.borderTopWidth, cs.borderRightWidth, cs.borderBottomWidth, cs.borderLeftWidth],
            radius: cs.borderTopLeftRadius };
        }
        return out;
      })()
    JS
    %w[header tablist legend panel].each do |name|
      box = boxes[name]
      assert_includes [ "rgba(0, 0, 0, 0)", boxes["body"] ], box["bg"], "#{name} background"
      assert_equal "none", box["shadow"], "#{name} box-shadow"
      assert_equal %w[0px 0px 0px 0px], box["borders"], "#{name} borders"
      assert_equal "0px", box["radius"], "#{name} radius"
    end
  end

  test "the calendar page content starts at the gutter, aligned with the table" do
    visit operations_calendar_path(start: "2026-03-01", days: 7)

    left, table_left, gutter = page.evaluate_script(<<~JS)
      (() => {
        const rem = parseFloat(getComputedStyle(document.documentElement).fontSize);
        const g = parseFloat(getComputedStyle(document.body).getPropertyValue("--oc-gutter")) * rem;
        return [document.querySelector("body.oc-page .app-page-header").getBoundingClientRect().left,
                document.querySelector("table.oc-ledger").getBoundingClientRect().left, g];
      })()
    JS
    assert_in_delta 3 * 13, gutter, 0.5, "the wide-screen gutter is 3rem"
    assert_in_delta gutter, left, 1
    assert_in_delta left, table_left, 1
  end

  test "the calendar page does not scroll sideways when the table fits" do
    visit operations_calendar_path(start: "2026-03-01", days: 7)

    widths = page.evaluate_script("[document.documentElement.scrollWidth, document.documentElement.clientWidth, document.querySelector('table.oc-ledger').getBoundingClientRect().right]")
    skip "table is wider than the window" if widths[2] > widths[1]
    assert_operator widths[0], :<=, widths[1]
  end

  test "the canvas is the page colour when the table is wider than the page" do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    visit operations_calendar_path(start: "2026-03-01", days: 7)
    assert_selector "table.oc-ledger td.ledger-day", minimum: 1

    page.execute_script("document.querySelector('.oc-ledger thead th:last-child').style.minWidth = '1500px'")
    page.execute_script("window.scrollTo(document.documentElement.scrollWidth, 0)")

    colours = page.evaluate_script("[getComputedStyle(document.documentElement).backgroundColor, getComputedStyle(document.body).backgroundColor]")
    assert_equal colours[1], colours[0], "the canvas must match the page colour"
  end

  test "the page spans a table wider than the main column, keeping navbar, header and tabs in view at the far right" do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    visit operations_calendar_path(start: "2026-03-01", days: 7)
    assert_selector "table.oc-ledger td.ledger-day", minimum: 1

    page.execute_script("document.querySelector('.oc-ledger thead th:last-child').style.minWidth = '1500px'")
    page.execute_script("window.scrollTo(document.documentElement.scrollWidth, 0)")

    geometry = page.evaluate_script(<<~JS)
      (() => {
        const left = (selector) => document.querySelector(selector).getBoundingClientRect().left;
        return {
          body: document.body.getBoundingClientRect().right,
          table: document.querySelector("table.oc-ledger").getBoundingClientRect().right,
          navbar: left(".app-navbar"), header: left(".app-page-header"), tabs: left("[role=tablist]")
        };
      })()
    JS
    assert_operator geometry["body"], :>=, geometry["table"], "the body reaches the table's right edge"
    assert_in_delta 0, geometry["navbar"], 1
    assert_operator geometry["header"], :>=, 0
    assert_operator geometry["tabs"], :>=, 0
  end

  test "data cells are white on every day of every tab, with no zebra" do
    hospitalizations(:two).update_columns(purpose: "examination", scheduled_procedure_date: Date.new(2026, 3, 2), scheduled_admission_date: Date.new(2026, 3, 1), admission_date: nil, discharge_date: nil)
    [ [ "surgery", "tr.oc-surgery:not(.ledger-row-urgent):not(.ledger-row-offslot)" ], [ "examination", "tr.oc-exam" ] ].each do |view, row|
      visit operations_calendar_path(start: "2026-03-01", days: 14, view: view)
      colours = page.evaluate_script(<<~JS)
        (() => {
          const tds = [...document.querySelectorAll("tbody.oc-day #{row} td:not(.ledger-day)")];
          return [tds.length, [...new Set(tds.map((td) => getComputedStyle(td).backgroundColor))]];
        })()
      JS
      assert_operator colours[0], :>, 0, "#{view} has data cells"
      assert_equal [ "rgb(255, 255, 255)" ], colours[1], "#{view} data cells are all white"
    end
  end

  test "a plain cell is white on a day" do
    visit operations_calendar_path(start: "2026-03-01", days: 7)

    color = page.evaluate_script(<<~JS)
      (() => {
        const td = document.querySelector("tbody.oc-day:not(.oc-day-highlight) tr.oc-surgery:not(.ledger-row-urgent):not(.ledger-row-offslot) td.ledger-patient");
        return td && getComputedStyle(td).backgroundColor;
      })()
    JS
    assert_equal "rgb(255, 255, 255)", color
  end

  test "columns up to the patient column stay in view while the page scrolls sideways" do
    page.driver.browser.manage.window.resize_to(700, 1000)
    visit operations_calendar_path(start: "2026-03-01", days: 7)
    assert_frozen_columns "table.oc-ledger thead th:nth-child(4)", "tr.oc-surgery td.ledger-patient"
  end

  test "the examination tab freezes its patient column too" do
    hospitalizations(:two).update_columns(purpose: "examination", scheduled_procedure_date: Date.new(2026, 3, 5),
                                          scheduled_admission_date: Date.new(2026, 3, 5), admission_date: nil, discharge_date: nil)
    page.driver.browser.manage.window.resize_to(500, 1000)
    visit operations_calendar_path(start: "2026-03-01", days: 7, view: "examination")
    assert_selector "tr.oc-exam td.ledger-patient"
    assert_frozen_columns "table.oc-ledger thead th:nth-child(5)", "tr.oc-exam td.ledger-patient"
  end

  # Once the page has scrolled past the gutter, the patient header/cell keep
  # their left however far it scrolls on (they stick right after the day and
  # earlier columns), while a later column keeps moving with the page.
  def assert_frozen_columns(later_header, patient_row_selector)
    lefts = <<~JS
      (() => {
        const l = (el) => el.getBoundingClientRect().left;
        return [l(document.querySelector("table.oc-ledger thead th[data-freeze-key=patient]")),
                l(document.querySelector("#{patient_row_selector}")),
                l(document.querySelector("#{later_header}"))];
      })()
    JS
    max = page.evaluate_script("document.scrollingElement.scrollWidth - document.documentElement.clientWidth")
    assert_operator max, :>, 150, "the window should be narrow enough to scroll sideways"
    page.execute_script("window.scrollTo(100, 0)")
    first = page.evaluate_script(lefts)
    page.execute_script("window.scrollTo(#{max}, 0)")
    second = page.evaluate_script(lefts)

    assert_in_delta first[0], second[0], 1, "patient header moved"
    assert_in_delta first[1], second[1], 1, "patient cell moved"
    assert_operator first[2] - second[2], :>, max - 100 - 2, "a later column should scroll away"
    assert_operator second[0], :>, 0
  end
end
