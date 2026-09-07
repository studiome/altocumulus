require "test_helper"

# Stage 3 group 4b: locale coverage for the Dashboard screen
# (DashboardController#index and its view). `year: "1999"` is used to force
# every breakdown/top-N section into its "no data" branch deterministically
# (LedgerStatistics scopes everything but total_patients to the given year),
# so the "No data" translation is exercised without depending on which
# fixture years happen to have surgeries/hospitalizations today.
class DashboardI18nTest < ActionDispatch::IntegrationTest
  test "index renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get dashboard_url

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
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end

  test "index renders in English unchanged" do
    sign_in_as(users(:member))

    get dashboard_url

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
  end

  test "average length of stay renders with the Japanese days unit" do
    sign_in_as(users(:japanese_member))

    get dashboard_url

    assert_response :success
    stats = LedgerStatistics.new(year: nil)
    if stats.average_length_of_stay
      assert_match(/#{Regexp.escape(stats.average_length_of_stay.to_s)}日/, response.body)
    else
      assert_select "div.stat-value", text: "-"
    end
  end

  test "average length of stay renders with the original English days unit" do
    sign_in_as(users(:member))

    get dashboard_url

    assert_response :success
    stats = LedgerStatistics.new(year: nil)
    if stats.average_length_of_stay
      assert_match(/#{Regexp.escape(stats.average_length_of_stay.to_s)} days/, response.body)
    else
      assert_select "div.stat-value", text: "-"
    end
  end

  test "empty breakdown sections render the Japanese no-data copy for a year with no records" do
    sign_in_as(users(:japanese_member))

    get dashboard_url, params: { year: "1999" }

    assert_response :success
    assert_select "p", text: "データがありません", minimum: 5
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end

  test "empty breakdown sections render the original English no-data copy for a year with no records" do
    sign_in_as(users(:member))

    get dashboard_url, params: { year: "1999" }

    assert_response :success
    assert_select "p", text: "No data", minimum: 5
  end
end
