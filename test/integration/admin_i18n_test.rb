require "test_helper"

# Stage 3 (view text externalization), group 4a: the Admin screens (Users /
# Announcements / AdminNotes) plus their controllers' flash messages.
# Follows the pattern set by MasterDataI18nTest / PatientsI18nTest: Japanese
# rendering, byte-identical English rendering, and no missing translation
# keys.
class AdminI18nTest < ActionDispatch::IntegrationTest
  setup { sign_out }

  # ---------------------------------------------------------------------
  # translation missing coverage
  # ---------------------------------------------------------------------

  test "no translation missing on admin screens rendered in Japanese" do
    sign_in_as(users(:japanese_admin))

    user = users(:member)
    announcement = announcements(:published_one)

    [
      admin_users_url,
      new_admin_user_url,
      edit_admin_user_url(user),
      admin_announcements_url,
      new_admin_announcement_url,
      edit_admin_announcement_url(announcement),
      admin_admin_notes_url
    ].each do |url|
      get url
      assert_response :success, "expected #{url} to render successfully in ja"
      assert_no_match(/[Tt]ranslation missing/, response.body, "translation missing while rendering #{url}")
    end
  end

  # ---------------------------------------------------------------------
  # Users
  # ---------------------------------------------------------------------

  test "users screens render in Japanese" do
    sign_in_as(users(:japanese_admin))

    get admin_users_url
    assert_select "h1", text: "利用者"
    assert_select "a", text: "新規利用者"
    assert_select "th", text: "操作"
    assert_select "a", text: "編集"

    get new_admin_user_url
    assert_select "h1", text: "新規利用者"

    get edit_admin_user_url(users(:member))
    assert_select "h1", text: "利用者を編集"
  end

  test "users screens render unchanged in English" do
    sign_in_as(users(:admin))

    get admin_users_url
    assert_select "h1", text: "Users"
    assert_select "a", text: "New User"
    assert_select "th", text: "Actions"
    assert_select "a", text: "Edit"

    get new_admin_user_url
    assert_select "h1", text: "New User"

    get edit_admin_user_url(users(:member))
    assert_select "h1", text: "Edit User"
  end

  test "user create/update flash messages render in Japanese" do
    sign_in_as(users(:japanese_admin))

    post admin_users_url, params: { user: { name: "New User", login_id: "new-ja@example.com", password: "password", password_confirmation: "password", role: "user", active: true } }
    follow_redirect!
    assert_match "利用者を作成しました。", response.body

    user = users(:member)
    patch admin_user_url(user), params: { user: { name: user.name, login_id: user.login_id, role: "admin", active: true } }
    follow_redirect!
    assert_match "利用者を更新しました。", response.body
  end

  test "user create/update flash messages render unchanged in English" do
    sign_in_as(users(:admin))

    post admin_users_url, params: { user: { name: "New User", login_id: "new-en@example.com", password: "password", password_confirmation: "password", role: "user", active: true } }
    follow_redirect!
    assert_match "User was successfully created.", response.body

    user = users(:member)
    patch admin_user_url(user), params: { user: { name: user.name, login_id: user.login_id, role: "admin", active: true } }
    follow_redirect!
    assert_match "User was successfully updated.", response.body
  end

  test "reset password flash message includes the temporary password in Japanese" do
    sign_in_as(users(:japanese_admin))

    patch reset_password_admin_user_url(users(:member))
    follow_redirect!
    assert_match(/パスワードをリセットしました。仮パスワード: \S+/, response.body)
  end

  test "reset password flash message renders unchanged in English" do
    sign_in_as(users(:admin))

    patch reset_password_admin_user_url(users(:member))
    follow_redirect!
    assert_match(/Password was reset\. Temporary password: \S+/, response.body)
  end

  # ---------------------------------------------------------------------
  # Announcements
  # ---------------------------------------------------------------------

  test "announcements screens render in Japanese" do
    sign_in_as(users(:japanese_admin))
    announcement = announcements(:published_one)

    get admin_announcements_url
    assert_select "h1", text: "お知らせ"
    assert_select "a", text: "新規お知らせ"
    assert_select "span", text: "公開済み"

    get edit_admin_announcement_url(announcement)
    assert_select "h1", text: "お知らせを編集"
  end

  test "announcements screens render unchanged in English" do
    sign_in_as(users(:admin))
    announcement = announcements(:published_one)

    get admin_announcements_url
    assert_select "h1", text: "Announcements"
    assert_select "a", text: "New Announcement"
    assert_select "span", text: "Published"

    get edit_admin_announcement_url(announcement)
    assert_select "h1", text: "Edit Announcement"
  end

  test "announcement flash messages render in Japanese" do
    sign_in_as(users(:japanese_admin))

    post admin_announcements_url, params: { announcement: { title: "Notice", body: "Body", published: true } }
    follow_redirect!
    assert_match "お知らせを作成しました。", response.body

    announcement = Announcement.last
    patch admin_announcement_url(announcement), params: { announcement: { title: "Updated", body: "Body", published: false } }
    follow_redirect!
    assert_match "お知らせを更新しました。", response.body

    delete admin_announcement_url(announcement)
    follow_redirect!
    assert_match "お知らせを削除しました。", response.body
  end

  test "announcement flash messages render unchanged in English" do
    sign_in_as(users(:admin))

    post admin_announcements_url, params: { announcement: { title: "Notice", body: "Body", published: true } }
    follow_redirect!
    assert_match "Announcement was successfully created.", response.body

    announcement = Announcement.last
    patch admin_announcement_url(announcement), params: { announcement: { title: "Updated", body: "Body", published: false } }
    follow_redirect!
    assert_match "Announcement was successfully updated.", response.body

    delete admin_announcement_url(announcement)
    follow_redirect!
    assert_match "Announcement was successfully deleted.", response.body
  end

  test "announcement delete confirmation prompt is translated in Japanese" do
    sign_in_as(users(:japanese_admin))

    get admin_announcements_url
    assert_match(/data-turbo-confirm="この[^"]*お知らせ[^"]*を削除しますか[?？]"/, response.body)
  end

  test "announcement delete confirmation prompt is unchanged in English" do
    sign_in_as(users(:admin))

    get admin_announcements_url
    assert_match('data-turbo-confirm="Delete this announcement?"', response.body)
  end

  # ---------------------------------------------------------------------
  # Admin Notes
  # ---------------------------------------------------------------------

  test "admin notes screen renders in Japanese" do
    sign_in_as(users(:japanese_admin))

    get admin_admin_notes_url
    assert_select "h1", text: "管理者メモ"
    assert_select "th", text: "操作"
  end

  test "admin notes screen renders unchanged in English" do
    sign_in_as(users(:admin))

    get admin_admin_notes_url
    assert_select "h1", text: "Admin Notes"
    assert_select "th", text: "Actions"
  end

  test "admin note create flash message renders in Japanese" do
    sign_in_as(users(:japanese_admin))

    post admin_admin_notes_url, params: { admin_note: { body: "Test note" } }
    follow_redirect!
    assert_match "メモを追加しました。", response.body
  end

  test "admin note create flash message renders unchanged in English" do
    sign_in_as(users(:admin))

    post admin_admin_notes_url, params: { admin_note: { body: "Test note" } }
    follow_redirect!
    assert_match "Note was successfully added.", response.body
  end

  test "admin note destroy flash message renders in Japanese" do
    sign_in_as(users(:japanese_admin))

    delete admin_admin_note_url(admin_notes(:one))
    follow_redirect!
    assert_match "メモを削除しました。", response.body
  end

  test "admin note destroy flash message renders unchanged in English" do
    sign_in_as(users(:admin))

    delete admin_admin_note_url(admin_notes(:one))
    follow_redirect!
    assert_match "Note was successfully deleted.", response.body
  end

  # ---------------------------------------------------------------------
  # form validation error headings
  # ---------------------------------------------------------------------

  test "user form validation errors heading renders in Japanese" do
    sign_in_as(users(:japanese_admin))

    post admin_users_url, params: { user: { name: "", login_id: "", password: "", password_confirmation: "", role: "user", active: true } }

    assert_response :unprocessable_entity
    assert_match(/件のエラーによりこの利用者を保存できませんでした:/, response.body)
  end

  test "user form validation errors heading renders in English" do
    sign_in_as(users(:admin))

    post admin_users_url, params: { user: { name: "", login_id: "", password: "", password_confirmation: "", role: "user", active: true } }

    assert_response :unprocessable_entity
    assert_match(/errors? prohibited this user from being saved:/, response.body)
  end
end
