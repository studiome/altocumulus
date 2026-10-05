# Shared helpers for the locale integration tests (*_i18n_test.rb). Fixture
# users: member/admin render English, japanese_member/japanese_admin render
# Japanese, so a test can look at the same screen in both locales by switching
# the signed-in user.
module I18nIntegrationHelper
  # Signs in as +user+ (dropping any previous session) and GETs +url+.
  def get_as(user, url, params = {})
    sign_in_fresh(user)
    get url, params: params
  end

  def sign_in_fresh(user)
    sign_out
    sign_in_as(user)
  end

  # Signs in as +user+ and asserts that every URL renders successfully without
  # a missing translation.
  def assert_no_translation_missing(urls, as:)
    sign_in_fresh(as)
    Array(urls).each do |url|
      get url
      assert_response :success, "expected #{url} to render successfully in ja"
      assert_no_match(/[Tt]ranslation missing/, response.body, "translation missing while rendering #{url}")
    end
  end
end
