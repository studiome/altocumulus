require "test_helper"
require_relative "i18n_integration_helper"

# i18n of the Operations Calendar screen (OperationsCalendarController#index
# and its `_day` partials). A fixed `start`/`days` window is passed so the
# fixture surgeries, holidays and slot rules inside it are deterministic:
#
#   2026-03-01 (Sun) -- no elective slot rule, has an emergency surgery
#   2026-03-02 (Mon) -- no elective slot rule, one elective surgery
#     (counts toward "Outside Regular Surgery Days")
#   2026-03-03 (Tue) -- 3 elective slots x 240 min configured; slot 1 holds
#     two surgeries (120 min used), slot 2 holds one (300 min, 60 min over)
#   2026-03-04 (Wed) -- 2 elective slots x 180 min configured, no surgeries
#   2026-03-10 (Tue) -- a closed holiday (Vernal Equinox Day fixture)
#
# The English "No surgeries scheduled" copy and the "Operations Calendar" h1
# are already asserted by operations_calendar_controller_test.rb ("a day
# without surgeries still shows its date and a placeholder row", "root routes
# to the operations calendar").
class OperationsCalendarI18nTest < ActionDispatch::IntegrationTest
  include I18nIntegrationHelper

  WINDOW = { start: "2026-03-01", days: 10 }.freeze

  test "index header renders in Japanese and English" do
    get_as users(:japanese_member), operations_calendar_url, WINDOW

    assert_response :success
    assert_select "h1", text: "運用カレンダー"
    assert_select "p.app-page-kicker", text: "手術"
    assert_select "label.app-filter-label", text: "開始"
    assert_select "label.app-filter-label", text: "日数"
    assert_select "input[type=submit][value=?]", "適用"
    assert_select "a", text: "今日"
    assert_select "th span", text: "術者"
    assert_select "th span", text: "枠"
    assert_match "2026年03月01日", response.body
    assert_match "2026年03月10日", response.body
    assert_match(/10日/, response.body)

    get_as users(:member), operations_calendar_url, WINDOW

    assert_response :success
    assert_select "p.app-page-kicker", text: "Operations"
    assert_select "label.app-filter-label", text: "Start"
    assert_select "label.app-filter-label", text: "Days"
    assert_select "input[type=submit][value=?]", "Apply"
    assert_select "a", text: "Today"
    assert_select "th span", text: "Operator"
    assert_select "th span", text: "Slot"
    assert_match "March 01, 2026", response.body
    assert_match "March 10, 2026", response.body
    assert_match(/10 days/, response.body)
    assert_no_match(/運用カレンダー/, response.body)
  end

  test "day partial renders in Japanese and English" do
    get_as users(:japanese_member), operations_calendar_url, WINDOW

    assert_response :success
    assert_match "火曜日", response.body
    assert_match "休診: Vernal Equinox Day", response.body
    assert_match "手術枠なし(休日)", response.body
    assert_select "span.badge-error", text: "緊急"
    assert_match "手術枠未設定", response.body
    assert_match "入院数", response.body
    assert_match(%r{2 / 3枠}, response.body)
    assert_match(%r{\(420 / 720分\)}, response.body)
    assert_match "手術の予定はありません", response.body

    get_as users(:member), operations_calendar_url, WINDOW

    assert_response :success
    assert_match "Tuesday", response.body
    assert_match "Closed: Vernal Equinox Day", response.body
    assert_match "No elective slots (holiday)", response.body
    assert_select "span.badge-error", text: "Emergency"
    assert_match "No slots configured", response.body
    assert_match "Admissions:", response.body
    assert_match(%r{2 / 3 slots}, response.body)
    assert_match(%r{\(420 / 720 min\)}, response.body)
  end

  test "invalid date range alert renders in Japanese and English" do
    get_as users(:japanese_member), operations_calendar_url, { start: "not-a-date" }

    assert_redirected_to operations_calendar_path
    follow_redirect!
    assert_match "指定された日付範囲が正しくありません。既定の範囲を表示します。", response.body

    get_as users(:member), operations_calendar_url, { start: "not-a-date" }

    assert_redirected_to operations_calendar_path
    follow_redirect!
    assert_match "The requested date range was invalid. Showing the default range instead.", response.body
  end
end
