require "test_helper"
require_relative "i18n_integration_helper"

# i18n of the Accounts#show screen (My Account) and its controller flash.
class AccountsI18nTest < ActionDispatch::IntegrationTest
  include I18nIntegrationHelper

  test "account screen renders in Japanese and English" do
    get_as users(:japanese_member), account_url
    assert_select "h1", text: "アカウント"
    assert_select "div.divider", text: "パスワードの変更"
    assert_select "label", text: "現在のパスワード"
    assert_select "label", text: "新しいパスワード"
    assert_select "label", text: "新しいパスワード(確認)"

    get_as users(:member), account_url
    assert_select "h1", text: "My Account"
    assert_select "div.divider", text: "Change Password"
    assert_select "label", text: "Current Password"
    assert_select "label", text: "New Password"
    assert_select "label", text: "Confirm New Password"
  end

  test "update flash notice renders in Japanese and English" do
    {
      users(:japanese_member) => "アカウントを更新しました。",
      users(:member) => "Account was successfully updated."
    }.each do |user, notice|
      sign_in_fresh(user)

      patch account_url, params: { user: { name: "Updated Name", login_id: user.login_id } }

      follow_redirect!
      assert_match notice, response.body
    end
  end

  test "form validation errors heading renders in Japanese and pluralizes in English" do
    sign_in_fresh(users(:japanese_member))
    patch account_url, params: { user: { name: "", login_id: "" } }
    assert_response :unprocessable_entity
    assert_match(/件のエラーによりこのアカウントを保存できませんでした:/, response.body)

    sign_in_fresh(users(:member))
    patch account_url, params: { user: { name: "", login_id: "" } }
    assert_response :unprocessable_entity
    assert_match(/errors? prohibited this account from being saved:/, response.body)
  end
end
