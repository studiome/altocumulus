require "test_helper"

# Stage 3 (view text externalization), group 4a: the Accounts#show screen
# (My Account) and its controller flash.
class AccountsI18nTest < ActionDispatch::IntegrationTest
  setup { sign_out }

  test "no translation missing on account screen rendered in Japanese" do
    sign_in_as(users(:japanese_member))

    get account_url

    assert_response :success
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end

  test "account screen renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get account_url

    assert_select "h1", text: "アカウント"
    assert_select "div.divider", text: "パスワードの変更"
    assert_select "label", text: "現在のパスワード"
    assert_select "label", text: "新しいパスワード"
    assert_select "label", text: "新しいパスワード(確認)"
  end

  test "account screen renders unchanged in English" do
    sign_in_as(users(:member))

    get account_url

    assert_select "h1", text: "My Account"
    assert_select "div.divider", text: "Change Password"
    assert_select "label", text: "Current Password"
    assert_select "label", text: "New Password"
    assert_select "label", text: "Confirm New Password"
  end

  test "update flash notice renders in Japanese" do
    sign_in_as(users(:japanese_member))
    user = users(:japanese_member)

    patch account_url, params: { user: { name: "Updated Name", email: user.email } }

    follow_redirect!
    assert_match "アカウントを更新しました。", response.body
  end

  test "update flash notice renders unchanged in English" do
    sign_in_as(users(:member))
    user = users(:member)

    patch account_url, params: { user: { name: "Updated Name", email: user.email } }

    follow_redirect!
    assert_match "Account was successfully updated.", response.body
  end

  test "form validation errors heading renders in Japanese" do
    sign_in_as(users(:japanese_member))

    patch account_url, params: { user: { name: "", email: "" } }

    assert_response :unprocessable_entity
    assert_match(/件のエラーによりこのアカウントを保存できませんでした:/, response.body)
  end

  test "form validation errors heading renders in English" do
    sign_in_as(users(:member))

    patch account_url, params: { user: { name: "", email: "" } }

    assert_response :unprocessable_entity
    assert_match(/errors? prohibited this account from being saved:/, response.body)
  end
end
