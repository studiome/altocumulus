require "test_helper"
require_relative "i18n_integration_helper"

# i18n of the cross-search screen (SearchesController#index and its view).
# keyword: "John" matches patient :one ("John Doe") by name, and therefore also
# its linked hospitalizations and surgeries (Hospitalization/Surgery.filtered
# both join through the patient's name) -- a deterministic "results found"
# case. A keyword that matches nothing exercises the three "No matching ..."
# empty states.
class SearchesI18nTest < ActionDispatch::IntegrationTest
  include I18nIntegrationHelper

  test "index blank-keyword state renders in Japanese and English" do
    get_as users(:japanese_member), search_url

    assert_response :success
    assert_select "h1", text: "検索"
    assert_select "p.app-page-kicker", text: "横断検索"
    assert_select "label.app-filter-label", text: "キーワード"
    assert_select "input[type=submit][value=?]", "検索"
    assert_match "上のキーワード欄に入力すると、患者・入院・手術を横断して検索できます。", response.body

    get_as users(:member), search_url

    assert_response :success
    assert_select "h1", text: "Search"
    assert_select "p.app-page-kicker", text: "Cross-Search"
    assert_select "label.app-filter-label", text: "Keyword"
    assert_select "input[type=submit][value=?]", "Search"
    assert_match "Enter a keyword above to search across patients, hospitalizations, and surgeries.", response.body
  end

  test "index with matching results renders headings, clear link, and dates in Japanese and English" do
    get_as users(:japanese_member), search_url, { keyword: "John" }

    assert_response :success
    assert_select "a", text: "クリア"
    assert_select "a[role=tab]", text: /\A入院 \(\d+\)\z/
    assert_select "a[role=tab]", text: /\A手術 \(\d+\)\z/
    assert_select "a[role=tab]", text: "患者 (1)"
    assert_select "a", text: "入院の一覧をすべて見る"
    assert_match "John Doe", response.body
    assert_match "2026年03月01日", response.body

    get_as users(:member), search_url, { keyword: "John" }

    assert_response :success
    assert_select "a", text: "Clear"
    assert_select "a[role=tab]", text: /\AHospitalizations \(\d+\)\z/
    assert_select "a[role=tab]", text: /\ASurgeries \(\d+\)\z/
    assert_select "a[role=tab]", text: "Patients (1)"
    assert_select "a", text: "See all in Hospitalizations"
    assert_match "John Doe", response.body
    assert_match "2026-03-01", response.body
  end

  test "index with no matches renders the empty-state copy in every tab in both locales" do
    { japanese_member: [ "一致する入院がありません。", "一致する手術がありません。", "一致する患者がいません。", "入院 (0)" ],
      member: [ "No matching hospitalizations.", "No matching surgeries.", "No matching patients.", "Hospitalizations (0)" ] }.each do |user, (hospitalizations, surgeries, patients, first_tab)|
      get_as users(user), search_url, { keyword: "zzzznotfound" }
      assert_response :success
      assert_select "a[role=tab][aria-selected=true]", text: first_tab
      assert_match hospitalizations, response.body

      get_as users(user), search_url, { keyword: "zzzznotfound", tab: "surgeries" }
      assert_match surgeries, response.body

      get_as users(user), search_url, { keyword: "zzzznotfound", tab: "patients" }
      assert_match patients, response.body
    end
  end
end
