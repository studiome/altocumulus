require "test_helper"
require_relative "i18n_integration_helper"

# i18n of the weekly Surgery Schedule board (SurgerySchedulesController#index
# and its views). week_of 2026-03-03 is a configured week (slot usage, overrun,
# emergency section); week_of 2026-02-25 contains a day without a slot rule.
class SurgerySchedulesI18nTest < ActionDispatch::IntegrationTest
  include I18nIntegrationHelper

  test "index renders in Japanese and English" do
    get_as users(:japanese_member), surgery_schedule_url, { week_of: "2026-03-03" }

    assert_response :success
    assert_select "h1", text: "手術スケジュール"
    assert_select "a", text: "前週"
    assert_select "a", text: "今週"
    assert_select "a", text: "次週"
    assert_select "a", text: "枠を設定"
    assert_select "a", text: "休日"
    assert_match "2026年03月02日", response.body
    assert_match(%r{120 / 240分}, response.body)
    assert_match(/第1枠/, response.body)
    assert_match(/空き/, response.body)
    assert_match(/枠未割り当て/, response.body)
    assert_match(/\+60分超過/, response.body)
    # the emergency section reuses the shared scheduling_type translation
    assert_select "div.divider", text: "緊急"

    get_as users(:member), surgery_schedule_url, { week_of: "2026-03-03" }

    assert_response :success
    assert_select "h1", text: "Surgery Schedule"
    assert_select "a", text: "Prev Week"
    assert_select "a", text: "This Week"
    assert_select "a", text: "Next Week"
    assert_select "a", text: "Configure slots"
    assert_select "a", text: "Holidays"
    assert_match "March 02, 2026", response.body
    assert_no_match(/スケジュール/, response.body)
  end

  test "index renders the unconfigured-day copy in Japanese" do
    get_as users(:japanese_member), surgery_schedule_url, { week_of: "2026-02-25" }

    assert_response :success
    assert_match(/日曜日には手術枠が設定されていません/, response.body)
    assert_match(/利用可能な枠なし/, response.body)
  end
end
