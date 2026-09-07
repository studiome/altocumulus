require "test_helper"

# Stage 3 group 3b: locale coverage for the weekly Surgery Schedule board
# (SurgerySchedulesController#index and its views). Mirrors
# surgeries_i18n_test.rb / hospitalizations_i18n_test.rb's structure.
class SurgerySchedulesI18nTest < ActionDispatch::IntegrationTest
  test "index renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get surgery_schedule_url, params: { week_of: "2026-03-03" }

    assert_response :success
    assert_select "h1", text: "手術スケジュール"
    assert_select "a", text: "前週"
    assert_select "a", text: "今週"
    assert_select "a", text: "次週"
    assert_select "a", text: "枠を設定"
    assert_select "a", text: "休日"
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end

  test "index renders in English unchanged" do
    sign_in_as(users(:member))

    get surgery_schedule_url, params: { week_of: "2026-03-03" }

    assert_response :success
    assert_select "h1", text: "Surgery Schedule"
    assert_select "a", text: "Prev Week"
    assert_select "a", text: "This Week"
    assert_select "a", text: "Next Week"
    assert_select "a", text: "Configure slots"
    assert_select "a", text: "Holidays"
    assert_no_match(/スケジュール/, response.body)
  end

  test "index week heading renders in the Japanese date format" do
    sign_in_as(users(:japanese_member))

    get surgery_schedule_url, params: { week_of: "2026-03-03" }

    assert_response :success
    assert_match "2026年03月02日", response.body
  end

  test "index week heading renders in the original English date format" do
    sign_in_as(users(:member))

    get surgery_schedule_url, params: { week_of: "2026-03-03" }

    assert_response :success
    assert_match "March 02, 2026", response.body
  end

  test "index slot usage summary renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get surgery_schedule_url, params: { week_of: "2026-03-03" }

    assert_response :success
    assert_match(%r{120 / 240分}, response.body)
    assert_match(/第1枠/, response.body)
    assert_match(/空き/, response.body)
    assert_match(/枠未割り当て/, response.body)
  end

  test "index emergency section renders in Japanese using the shared scheduling_type translation" do
    sign_in_as(users(:japanese_member))

    get surgery_schedule_url, params: { week_of: "2026-03-03" }

    assert_response :success
    assert_select "div.divider", text: "緊急"
  end

  test "index overrun badge renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get surgery_schedule_url, params: { week_of: "2026-03-03" }

    assert_response :success
    assert_match(/\+60分超過/, response.body)
  end

  test "index unconfigured-day warning still renders in Japanese (already localized in stage 2)" do
    sign_in_as(users(:japanese_member))

    get surgery_schedule_url, params: { week_of: "2026-02-25" }

    assert_response :success
    assert_match(/日曜日には手術枠が設定されていません/, response.body)
  end

  test "index no-slot-available copy renders in Japanese for an unconfigured day" do
    sign_in_as(users(:japanese_member))

    get surgery_schedule_url, params: { week_of: "2026-02-25" }

    assert_response :success
    assert_match(/利用可能な枠なし/, response.body)
  end

  test "no translation missing on the surgery schedule board rendered in Japanese" do
    sign_in_as(users(:japanese_member))

    [ "2026-02-25", "2026-03-03" ].each do |week_of|
      get surgery_schedule_url, params: { week_of: week_of }
      assert_response :success, "expected week_of=#{week_of} to render successfully in ja"
      assert_no_match(/[Tt]ranslation missing/, response.body, "translation missing for week_of=#{week_of}")
    end
  end
end
