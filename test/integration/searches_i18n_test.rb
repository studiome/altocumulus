require "test_helper"

# Stage 3 group 4b: locale coverage for the cross-search screen
# (SearchesController#index and its view). keyword: "John" matches patient
# :one ("John Doe") by name, and therefore also its linked hospitalizations
# and surgeries (Hospitalization/Surgery.filtered both join through the
# patient's name) -- giving a deterministic "results found" case. A keyword
# that matches nothing exercises the three "No matching ..." empty states.
class SearchesI18nTest < ActionDispatch::IntegrationTest
  test "index blank-keyword state renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get search_url

    assert_response :success
    assert_select "h1", text: "検索"
    assert_select "p.app-page-kicker", text: "横断検索"
    assert_select "label.app-filter-label", text: "キーワード"
    assert_select "input[type=submit][value=?]", "検索"
    assert_match "上のキーワード欄に入力すると、患者・入院・手術を横断して検索できます。", response.body
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end

  test "index blank-keyword state renders in English unchanged" do
    sign_in_as(users(:member))

    get search_url

    assert_response :success
    assert_select "h1", text: "Search"
    assert_select "p.app-page-kicker", text: "Cross-Search"
    assert_select "label.app-filter-label", text: "Keyword"
    assert_select "input[type=submit][value=?]", "Search"
    assert_match "Enter a keyword above to search across patients, hospitalizations, and surgeries.", response.body
  end

  test "index with matching results renders headings, clear link, and dates in Japanese" do
    sign_in_as(users(:japanese_member))

    get search_url, params: { keyword: "John" }

    assert_response :success
    assert_select "a", text: "クリア"
    assert_select "h2", text: "患者"
    assert_select "h2", text: "入院"
    assert_select "h2", text: "手術"
    assert_select "a", text: "患者の一覧をすべて見る"
    assert_select "a", text: "入院の一覧をすべて見る"
    assert_select "a", text: "手術の一覧をすべて見る"
    assert_match "John Doe", response.body
    assert_match "2026年03月01日", response.body
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end

  test "index with matching results renders headings, clear link, and dates in English unchanged" do
    sign_in_as(users(:member))

    get search_url, params: { keyword: "John" }

    assert_response :success
    assert_select "a", text: "Clear"
    assert_select "h2", text: "Patients"
    assert_select "h2", text: "Hospitalizations"
    assert_select "h2", text: "Surgeries"
    assert_select "a", text: "See all in Patients"
    assert_select "a", text: "See all in Hospitalizations"
    assert_select "a", text: "See all in Surgeries"
    assert_match "John Doe", response.body
    assert_match "2026-03-01", response.body
  end

  test "index with no matches renders the Japanese empty-state copy in every section" do
    sign_in_as(users(:japanese_member))

    get search_url, params: { keyword: "zzzznotfound" }

    assert_response :success
    assert_match "一致する患者がいません。", response.body
    assert_match "一致する入院がありません。", response.body
    assert_match "一致する手術がありません。", response.body
  end

  test "index with no matches renders the original English empty-state copy in every section" do
    sign_in_as(users(:member))

    get search_url, params: { keyword: "zzzznotfound" }

    assert_response :success
    assert_match "No matching patients.", response.body
    assert_match "No matching hospitalizations.", response.body
    assert_match "No matching surgeries.", response.body
  end
end
