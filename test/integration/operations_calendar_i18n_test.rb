require "test_helper"

# Stage 3 group 4b: locale coverage for the Operations Calendar screen
# (OperationsCalendarController#index and its `_day` / `_summary_list`
# partials). Mirrors surgery_schedules_i18n_test.rb's structure -- a fixed
# `start`/`days` window is passed as params so the exact fixture surgeries,
# holidays, and slot rules that fall inside it are deterministic:
#
#   2026-03-01 (Sun) -- no elective slot rule, has an emergency surgery
#   2026-03-02 (Mon) -- no elective slot rule, one elective surgery
#     (counts toward "Outside Regular Surgery Days")
#   2026-03-03 (Tue) -- 3 elective slots x 240 min configured; slot 1 holds
#     two surgeries (120 min used), slot 2 holds one (300 min, 60 min over)
#   2026-03-04 (Wed) -- 2 elective slots x 180 min configured, no surgeries
#     (exercises "no surgeries scheduled" independent of slot configuration)
#   2026-03-10 (Tue) -- a closed holiday (Vernal Equinox Day fixture)
class OperationsCalendarI18nTest < ActionDispatch::IntegrationTest
  WINDOW = { start: "2026-03-01", days: 10 }.freeze

  test "index renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get operations_calendar_url, params: WINDOW

    assert_response :success
    assert_select "h1", text: "運用カレンダー"
    assert_select "p.app-page-kicker", text: "手術"
    assert_select "label.app-filter-label", text: "開始"
    assert_select "label.app-filter-label", text: "日数"
    assert_select "input[type=submit][value=?]", "適用"
    assert_select "a", text: "今日"
    assert_select "h3", text: "日程未定の手術"
    assert_select "h3", text: "通常の手術日以外の手術"
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end

  test "index renders in English unchanged" do
    sign_in_as(users(:member))

    get operations_calendar_url, params: WINDOW

    assert_response :success
    assert_select "h1", text: "Operations Calendar"
    assert_select "p.app-page-kicker", text: "Operations"
    assert_select "label.app-filter-label", text: "Start"
    assert_select "label.app-filter-label", text: "Days"
    assert_select "input[type=submit][value=?]", "Apply"
    assert_select "a", text: "Today"
    assert_select "h3", text: "Undated Surgeries"
    assert_select "h3", text: "Outside Regular Surgery Days"
    assert_no_match(/運用カレンダー/, response.body)
  end

  test "index date range heading renders in the Japanese date format with a Japanese day count" do
    sign_in_as(users(:japanese_member))

    get operations_calendar_url, params: WINDOW

    assert_response :success
    assert_match "2026年03月01日", response.body
    assert_match "2026年03月10日", response.body
    assert_match(/10日/, response.body)
  end

  test "index date range heading renders in the original English date format with an English day count" do
    sign_in_as(users(:member))

    get operations_calendar_url, params: WINDOW

    assert_response :success
    assert_match "March 01, 2026", response.body
    assert_match "March 10, 2026", response.body
    assert_match(/10 days/, response.body)
  end

  # Guards against re-defining a translation that already lives on the model
  # (Hospitalization.status_filter_options) -- the summary headings must
  # reuse it, not duplicate the Japanese string here in a second key.
  test "summary headings reuse Hospitalization.status_filter_options rather than a duplicate translation" do
    sign_in_as(users(:japanese_member))

    get operations_calendar_url, params: WINDOW

    assert_response :success
    I18n.with_locale(:ja) do
      assert_select "h3", text: Hospitalization.status_filter_options["waiting"]
      assert_select "h3", text: Hospitalization.status_filter_options["upcoming"]
      assert_select "h3", text: Hospitalization.status_filter_options["unconfirmed"]
      assert_select "h3", text: Hospitalization.status_filter_options["recently_updated"]
      assert_select "h3", text: Hospitalization.status_filter_options["referred"]
    end
  end

  test "day partial renders weekday, holiday badge, and no-slots-holiday copy in Japanese" do
    sign_in_as(users(:japanese_member))

    get operations_calendar_url, params: WINDOW

    assert_response :success
    assert_match "火曜日", response.body
    assert_match "休診: Vernal Equinox Day", response.body
    assert_match "手術枠なし(休日)", response.body
  end

  test "day partial renders weekday, holiday badge, and no-slots-holiday copy in English unchanged" do
    sign_in_as(users(:member))

    get operations_calendar_url, params: WINDOW

    assert_response :success
    assert_match "Tuesday", response.body
    assert_match "Closed: Vernal Equinox Day", response.body
    assert_match "No elective slots (holiday)", response.body
  end

  test "day partial renders emergency badge and unconfigured-day copy in Japanese" do
    sign_in_as(users(:japanese_member))

    get operations_calendar_url, params: WINDOW

    assert_response :success
    assert_select "span.badge-error", text: "緊急"
    assert_match "手術枠未設定", response.body
    assert_match "入院数", response.body
  end

  test "day partial renders emergency badge and unconfigured-day copy in English unchanged" do
    sign_in_as(users(:member))

    get operations_calendar_url, params: WINDOW

    assert_response :success
    assert_select "span.badge-error", text: "Emergency"
    assert_match "No slots configured", response.body
    assert_match "Admissions:", response.body
  end

  test "day partial renders configured slot usage and no-surgeries copy in Japanese" do
    sign_in_as(users(:japanese_member))

    get operations_calendar_url, params: WINDOW

    assert_response :success
    assert_match(%r{2 / 3枠}, response.body)
    assert_match(%r{\(420 / 720分\)}, response.body)
    assert_match "手術の予定はありません", response.body
  end

  test "day partial renders configured slot usage and no-surgeries copy in English unchanged" do
    sign_in_as(users(:member))

    get operations_calendar_url, params: WINDOW

    assert_response :success
    assert_match(%r{2 / 3 slots}, response.body)
    assert_match(%r{\(420 / 720 min\)}, response.body)
    assert_match "No surgeries scheduled", response.body
  end

  test "outside-regular-day surgeries and undated-surgeries panels render in Japanese" do
    sign_in_as(users(:japanese_member))

    get operations_calendar_url, params: WINDOW

    assert_response :success
    assert_match "John Doe", response.body
    assert_match "なし", response.body
  end

  test "outside-regular-day surgeries and undated-surgeries panels render in English unchanged" do
    sign_in_as(users(:member))

    get operations_calendar_url, params: WINDOW

    assert_response :success
    assert_match "John Doe", response.body
    assert_match "None", response.body
  end

  test "invalid date range alert renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get operations_calendar_url, params: { start: "not-a-date" }

    assert_redirected_to operations_calendar_path
    follow_redirect!
    assert_match "指定された日付範囲が正しくありません。既定の範囲を表示します。", response.body
  end

  test "invalid date range alert renders in English unchanged" do
    sign_in_as(users(:member))

    get operations_calendar_url, params: { start: "not-a-date" }

    assert_redirected_to operations_calendar_path
    follow_redirect!
    assert_match "The requested date range was invalid. Showing the default range instead.", response.body
  end

  test "no translation missing across the calendar window rendered in Japanese" do
    sign_in_as(users(:japanese_member))

    get operations_calendar_url, params: WINDOW

    assert_response :success
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end
end
