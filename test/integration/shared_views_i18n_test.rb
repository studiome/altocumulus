require "test_helper"
require_relative "i18n_integration_helper"

# i18n of shared/_picker_modal.html.erb (the static fallback shown before the
# turbo-frame lazily loads diagnoses/picker's real content). The title and
# description are passed in by the rendering page -- the hospitalization form
# passes diagnoses.picker.* -- so only the shell's own "Loading..." and close
# labels live in the partial.
class SharedViewsI18nTest < ActionDispatch::IntegrationTest
  include I18nIntegrationHelper

  test "diagnosis picker modal shell renders in Japanese and English" do
    get_as users(:japanese_member), new_hospitalization_url

    assert_response :success
    assert_match "診断名を選択", response.body
    assert_match "診断名マスタを名称で検索してください。", response.body
    assert_match "読み込み中...", response.body
    # The modal backdrop's dismiss button reuses common.close like the header's
    # close control; it once had a hard-coded English "Close" aria-label.
    assert_match 'aria-label="閉じる"', response.body
    assert_no_match(/aria-label="Close"/, response.body)

    get_as users(:member), new_hospitalization_url

    assert_response :success
    assert_match "Select a Diagnosis", response.body
    assert_match "Search the diagnosis master by name.", response.body
    assert_match "Loading...", response.body
  end
end
