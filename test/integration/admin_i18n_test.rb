require "test_helper"
require_relative "i18n_integration_helper"

# i18n of the Admin screens (Users / Announcements / AdminNotes / Settings /
# UserImports) plus their controllers' flash messages and validation headings.
# Each test visits the screen in Japanese (japanese_admin) and in English
# (admin); the English text must stay byte-identical to the original.
class AdminI18nTest < ActionDispatch::IntegrationTest
  include I18nIntegrationHelper

  # ---------------------------------------------------------------------
  # Users
  # ---------------------------------------------------------------------

  test "users screens render in Japanese and English" do
    get_as users(:japanese_admin), admin_users_url
    assert_select "h1", text: "利用者"
    assert_select "a", text: "新規利用者"
    assert_select "th", text: "操作"
    assert_select "a", text: "編集"

    get new_admin_user_url
    assert_select "h1", text: "新規利用者"

    get edit_admin_user_url(users(:member))
    assert_select "h1", text: "利用者を編集"

    get_as users(:admin), admin_users_url
    assert_select "h1", text: "Users"
    assert_select "a", text: "New User"
    assert_select "th", text: "Actions"
    assert_select "a", text: "Edit"

    get new_admin_user_url
    assert_select "h1", text: "New User"

    get edit_admin_user_url(users(:member))
    assert_select "h1", text: "Edit User"
  end

  # The stored role stays an English key; only the rendered label is localized.
  test "user role renders localized in both locales while the stored value stays English" do
    get_as users(:japanese_admin), admin_users_url
    assert_select "span.badge", text: "管理者"
    assert_select "span.badge", text: "利用者"

    get edit_admin_user_url(users(:member))
    assert_select "label", text: "利用者"
    assert_select "label", text: "管理者"
    assert_select "label", text: "データ管理者"

    get_as users(:admin), admin_users_url
    assert_select "span.badge", text: "Admin"
    assert_select "span.badge", text: "User"
    assert_select "span.badge", text: "Data Manager"

    assert_equal %w[data_manager], users(:data_manager).roles
    assert_equal %w[user], users(:member).roles
    assert_equal %w[admin], users(:admin).roles
  end

  test "user create/update/reset-password flash messages render in Japanese and English" do
    {
      users(:japanese_admin) => [ "new-ja@example.com", "利用者を作成しました。", "利用者を更新しました。", /パスワードをリセットしました。仮パスワード: \S+/ ],
      users(:admin) => [ "new-en@example.com", "User was successfully created.", "User was successfully updated.", /Password was reset\. Temporary password: \S+/ ]
    }.each do |admin, (login_id, created, updated, reset)|
      sign_in_fresh(admin)

      post admin_users_url, params: { user: { name: "New User", login_id: login_id, password: "password", password_confirmation: "password", roles: [ "user" ], active: true } }
      follow_redirect!
      assert_match created, response.body

      user = users(:member)
      patch admin_user_url(user), params: { user: { name: user.name, login_id: user.login_id, roles: [ "admin" ], active: true } }
      follow_redirect!
      assert_match updated, response.body

      # the flash carries the generated temporary password
      patch reset_password_admin_user_url(user)
      follow_redirect!
      assert_match reset, response.body

      user.update!(roles: [ "user" ])
    end
  end

  # ---------------------------------------------------------------------
  # Announcements
  # ---------------------------------------------------------------------

  test "announcements screens render in Japanese and English" do
    announcement = announcements(:published_one)

    get_as users(:japanese_admin), admin_announcements_url
    assert_select "h1", text: "お知らせ"
    assert_select "a", text: "新規お知らせ"
    assert_select "span", text: "公開済み"
    assert_match(/data-turbo-confirm="この[^"]*お知らせ[^"]*を削除しますか[?？]"/, response.body)

    get edit_admin_announcement_url(announcement)
    assert_select "h1", text: "お知らせを編集"

    get_as users(:admin), admin_announcements_url
    assert_select "h1", text: "Announcements"
    assert_select "a", text: "New Announcement"
    assert_select "span", text: "Published"
    assert_match('data-turbo-confirm="Delete this announcement?"', response.body)

    get edit_admin_announcement_url(announcement)
    assert_select "h1", text: "Edit Announcement"
  end

  test "announcement flash messages render in Japanese and English" do
    {
      users(:japanese_admin) => %w[お知らせを作成しました。 お知らせを更新しました。 お知らせを削除しました。],
      users(:admin) => [ "Announcement was successfully created.", "Announcement was successfully updated.", "Announcement was successfully deleted." ]
    }.each do |admin, (created, updated, deleted)|
      sign_in_fresh(admin)

      post admin_announcements_url, params: { announcement: { title: "Notice", body: "Body", published: true } }
      follow_redirect!
      assert_match created, response.body

      announcement = Announcement.last
      patch admin_announcement_url(announcement), params: { announcement: { title: "Updated", body: "Body", published: false } }
      follow_redirect!
      assert_match updated, response.body

      delete admin_announcement_url(announcement)
      follow_redirect!
      assert_match deleted, response.body
    end
  end

  # ---------------------------------------------------------------------
  # Admin Notes
  # ---------------------------------------------------------------------

  test "admin notes screen renders in Japanese and English" do
    get_as users(:japanese_admin), admin_admin_notes_url
    assert_select "h1", text: "管理者メモ"
    assert_select "th", text: "操作"

    get_as users(:admin), admin_admin_notes_url
    assert_select "h1", text: "Admin Notes"
    assert_select "th", text: "Actions"
  end

  test "admin note create/destroy flash messages render in Japanese and English" do
    {
      users(:japanese_admin) => %w[メモを追加しました。 メモを削除しました。],
      users(:admin) => [ "Note was successfully added.", "Note was successfully deleted." ]
    }.each do |admin, (added, deleted)|
      sign_in_fresh(admin)

      post admin_admin_notes_url, params: { admin_note: { body: "Test note" } }
      follow_redirect!
      assert_match added, response.body

      delete admin_admin_note_url(AdminNote.last)
      follow_redirect!
      assert_match deleted, response.body
    end
  end

  # ---------------------------------------------------------------------
  # Settings
  # ---------------------------------------------------------------------

  test "settings screen and update flash render in Japanese and English" do
    get_as users(:japanese_admin), edit_admin_settings_url
    assert_select "h1", text: "設定"
    assert_select "input[type=submit][value='設定を保存']"

    patch admin_settings_url, params: { app_setting: { title: "新アプリ名" } }
    follow_redirect!
    assert_match "設定を更新しました。", response.body

    get_as users(:admin), edit_admin_settings_url
    assert_select "h1", text: "Settings"
    assert_select "input[type=submit][value='Save Settings']"

    patch admin_settings_url, params: { app_setting: { title: "New Title" } }
    follow_redirect!
    assert_match "Settings were successfully updated.", response.body
  end

  # ---------------------------------------------------------------------
  # User Imports
  # ---------------------------------------------------------------------

  test "user import screen renders in Japanese and English" do
    get_as users(:japanese_admin), new_admin_user_import_url
    assert_select "h1", text: "CSVで利用者を一括登録"
    assert_select "a", text: /テンプレートをダウンロード/
    assert_select "input[type=submit][value='取り込む']"

    get_as users(:admin), new_admin_user_import_url
    assert_select "h1", text: "Import Users from CSV"
    assert_select "a", text: /Download Template/
    assert_select "input[type=submit][value='Import']"
  end

  test "user import result screen renders in Japanese and English" do
    upload = lambda do |login_id, name|
      csv_data = <<~CSV
        login_id,password,name
        #{login_id},supersecret,#{name}
      CSV
      post admin_user_import_url, params: { user_import: { file: Rack::Test::UploadedFile.new(StringIO.new(csv_data), "text/csv", original_filename: "users.csv") } }
      assert_response :success
    end

    sign_in_fresh(users(:japanese_admin))
    upload.call("import-ja@example.com", "山田テスト")
    assert_select "h1", text: "取り込み結果"
    assert_match "登録1件、スキップ0件、失敗0件。", response.body
    assert_select "span.badge-success", text: "登録"
    assert_select "a", text: "利用者一覧へ戻る"

    sign_in_fresh(users(:admin))
    upload.call("import-en@example.com", "English Test")
    assert_select "h1", text: "Import Result"
    assert_match "1 registered, 0 skipped, 0 failed.", response.body
    assert_select "span.badge-success", text: "Registered"
    assert_select "a", text: "Back to Users"
  end

  # ---------------------------------------------------------------------
  # form validation error headings
  # ---------------------------------------------------------------------

  test "form validation errors headings render in Japanese and pluralize in English" do
    blank_user = { user: { name: "", login_id: "", password: "", password_confirmation: "", roles: [ "user" ], active: true } }

    sign_in_fresh(users(:japanese_admin))
    post admin_users_url, params: blank_user
    assert_response :unprocessable_entity
    assert_match(/件のエラーによりこの利用者を保存できませんでした:/, response.body)

    patch admin_settings_url, params: { app_setting: { title: "" } }
    assert_response :unprocessable_entity
    assert_match(/件のエラーにより設定を保存できませんでした:/, response.body)

    post admin_user_import_url, params: { user_import: { file: "" } }
    assert_response :unprocessable_entity
    assert_match(/件のエラーによりこのファイルを取り込めませんでした:/, response.body)

    sign_in_fresh(users(:admin))
    post admin_users_url, params: blank_user
    assert_response :unprocessable_entity
    assert_match(/errors? prohibited this user from being saved:/, response.body)

    patch admin_settings_url, params: { app_setting: { title: "" } }
    assert_response :unprocessable_entity
    assert_match(/errors? prohibited these settings from being saved:/, response.body)

    post admin_user_import_url, params: { user_import: { file: "" } }
    assert_response :unprocessable_entity
    assert_match(/errors? prohibited this file from being imported:/, response.body)
  end
end
