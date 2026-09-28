require "test_helper"

# i18n coverage for the case databases feature (data manager only screens for
# fields/create/edit/destroy, all-roles screens for index/show/entries),
# following the pattern set by MasterDataI18nTest.
class CaseDatabasesI18nTest < ActionDispatch::IntegrationTest
  setup { sign_out }

  test "no translation missing on case database screens rendered in Japanese" do
    data_manager = users(:data_manager)
    data_manager.update!(locale: "ja")
    sign_in_as(data_manager)

    case_database = case_databases(:registry)
    field = case_database_fields(:notes)
    entry = case_database_entries(:one)

    [
      case_databases_url,
      new_case_database_url,
      case_database_url(case_database),
      edit_case_database_url(case_database),
      new_case_database_field_url(case_database),
      edit_case_database_field_url(case_database, field),
      new_case_database_entry_url(case_database),
      edit_case_database_entry_url(case_database, entry)
    ].each do |url|
      get url
      assert_response :success, "expected #{url} to render successfully in ja"
      assert_no_match(/[Tt]ranslation missing/, response.body, "translation missing while rendering #{url}")
    end
  end

  test "case databases index and show render in Japanese for a regular member" do
    sign_in_as(users(:japanese_member))
    case_database = case_databases(:registry)

    get case_databases_url
    assert_response :success
    assert_select "h1", text: "症例データベース"

    get case_database_url(case_database)
    assert_response :success
    assert_select "a", text: "患者を追加"
    assert_select "a", text: "CSVエクスポート"
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end
end
