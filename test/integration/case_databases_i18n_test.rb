require "test_helper"
require_relative "i18n_integration_helper"

# i18n of the case databases feature (all-roles index/show screens). The
# data-manager-only screens (fields/create/edit/entries) are swept for missing
# translations in i18n_translation_missing_test.rb.
class CaseDatabasesI18nTest < ActionDispatch::IntegrationTest
  include I18nIntegrationHelper

  test "case databases index and show render in Japanese for a regular member" do
    case_database = case_databases(:registry)

    get_as users(:japanese_member), case_databases_url
    assert_response :success
    assert_select "h1", text: "症例データベース"

    get case_database_url(case_database)
    assert_response :success
    assert_select "a", text: "患者を追加"
    assert_select "a", text: "CSVエクスポート"
  end
end
