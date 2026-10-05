require "test_helper"
require_relative "i18n_integration_helper"

# i18n of the Dashboard screen (DashboardController#index and its view).
# `year: "1999"` forces every breakdown/top-N section into its "no data" branch
# deterministically (LedgerStatistics scopes everything but total_patients to
# the given year), so the "No data" translation is exercised without depending
# on which fixture years happen to have surgeries/hospitalizations today.
class DashboardI18nTest < ActionDispatch::IntegrationTest
  include I18nIntegrationHelper

  test "index renders in Japanese and English" do
    get_as users(:japanese_member), dashboard_url

    assert_response :success
    assert_select "h1", text: "ダッシュボード"
    assert_select "p.app-page-kicker", text: "概要"
    assert_select "label.app-filter-label", text: "年"
    assert_select "input[type=submit][value=?]", "表示"
    assert_select "div.stat-title", text: "総患者数"
    assert_select "div.stat-title", text: "現在の入院患者数"
    assert_select "div.stat-title", text: "手術件数"
    assert_select "div.stat-title", text: "入院件数"
    assert_select "div.stat-title", text: "平均入院日数"
    assert_select "h2", text: "月別手術件数"
    assert_select "h2", text: "月別入院件数"
    assert_select "h2", text: "上位術式"
    assert_select "h2", text: "入院時の上位診断名"
    assert_select "h2", text: "麻酔方法別内訳"
    assert_select "h2", text: "予定区分別内訳"
    assert_select "h2", text: "転帰別内訳"
    stats = LedgerStatistics.new(year: nil)
    if stats.average_length_of_stay
      assert_match(/#{Regexp.escape(stats.average_length_of_stay.to_s)}日/, response.body)
    else
      assert_select "div.stat-value", text: "-"
    end

    get_as users(:member), dashboard_url

    assert_response :success
    assert_select "h1", text: "Dashboard"
    assert_select "p.app-page-kicker", text: "Overview"
    assert_select "label.app-filter-label", text: "Year"
    assert_select "input[type=submit][value=?]", "View"
    assert_select "div.stat-title", text: "Total Patients"
    assert_select "div.stat-title", text: "Current Inpatients"
    assert_select "div.stat-title", text: "Surgeries"
    assert_select "div.stat-title", text: "Hospitalizations"
    assert_select "div.stat-title", text: "Avg. Length of Stay"
    assert_select "h2", text: "Monthly Surgeries"
    assert_select "h2", text: "Monthly Hospitalizations"
    assert_select "h2", text: "Top Procedures"
    assert_select "h2", text: "Top Diagnoses at Admission"
    assert_select "h2", text: "Anesthesia Method Breakdown"
    assert_select "h2", text: "Scheduling Type Breakdown"
    assert_select "h2", text: "Outcome Breakdown"
    assert_no_match(/ダッシュボード/, response.body)
    if stats.average_length_of_stay
      assert_match(/#{Regexp.escape(stats.average_length_of_stay.to_s)} days/, response.body)
    else
      assert_select "div.stat-value", text: "-"
    end
  end

  test "empty breakdown sections render the no-data copy in both locales for a year with no records" do
    get_as users(:japanese_member), dashboard_url, { year: "1999" }
    assert_response :success
    assert_select "p", text: "データがありません", minimum: 5

    get_as users(:member), dashboard_url, { year: "1999" }
    assert_response :success
    assert_select "p", text: "No data", minimum: 5
  end
end
