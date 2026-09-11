require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @member = users(:member)
  end

  test "valid user is valid" do
    user = User.new(login_id: "new@example.com", name: "New User", password: "password", password_confirmation: "password")
    assert user.valid?
  end

  test "requires email" do
    user = User.new(name: "No Email", password: "password")
    assert_not user.valid?
    assert_includes user.errors[:login_id], "can't be blank"
  end

  test "requires name" do
    user = User.new(login_id: "noname@example.com", password: "password")
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "email is normalized and uniqueness ignores case and whitespace" do
    user = User.new(login_id: "  ADMIN@Example.com  ", name: "Dup", password: "password")
    assert_not user.valid?
    assert_includes user.errors[:login_id], "has already been taken"
  end

  test "email is stored downcased and stripped" do
    user = User.create!(login_id: "  Mixed@Example.com  ", name: "Mixed Case", password: "password")
    assert_equal "mixed@example.com", user.login_id
  end

  test "password must be at least 8 characters" do
    user = User.new(login_id: "short@example.com", name: "Short", password: "short12")
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "role must be user or admin" do
    user = User.new(login_id: "role@example.com", name: "Role", password: "password", role: "superuser")
    assert_not user.valid?
    assert_includes user.errors[:role], "is not included in the list"
  end

  test "defaults locale to en" do
    user = User.create!(login_id: "default-locale@example.com", name: "Default Locale", password: "password")
    assert_equal "en", user.locale
  end

  test "locale must be en or ja" do
    user = User.new(login_id: "locale@example.com", name: "Locale", password: "password", locale: "de")
    assert_not user.valid?
    assert_includes user.errors[:locale], "is not included in the list"
  end

  test "accepts ja as a locale" do
    user = User.new(login_id: "ja-locale@example.com", name: "JA Locale", password: "password", locale: "ja")
    assert user.valid?
  end

  test "admin? reflects role" do
    assert @admin.admin?
    assert_not @member.admin?
  end

  test "active scope only returns active users" do
    assert_includes User.active, @admin
    assert_not_includes User.active, users(:inactive)
  end

  test "cannot deactivate the last active admin" do
    User.where(role: "admin").where.not(id: @admin.id).update_all(active: false)
    @admin.active = false
    assert_not @admin.valid?
    assert_includes @admin.errors[:base], "Cannot remove the last active admin"
  end

  test "cannot demote the last active admin" do
    User.where(role: "admin").where.not(id: @admin.id).update_all(active: false)
    @admin.role = "user"
    assert_not @admin.valid?
    assert_includes @admin.errors[:base], "Cannot remove the last active admin"
  end

  test "can deactivate an admin when another active admin remains" do
    other_admin = User.create!(login_id: "other-admin@example.com", name: "Other Admin", password: "password", role: "admin")
    @admin.active = false
    assert @admin.valid?
    assert other_admin.persisted?
  end

  # --- config.x.account_identifier (email/username) ---------------------

  test "identifier_mode defaults to email" do
    assert_equal "email", User.identifier_mode
    assert User.identifier_email?
    assert_not User.identifier_username?
  end

  test "identifier_mode falls back to email for an unrecognized config value" do
    with_account_identifier("bogus") do
      assert_equal "email", User.identifier_mode
    end
  end

  test "login_id must look like an email address in email mode" do
    user = User.new(login_id: "not-an-email", name: "Bad Format", password: "password")
    assert_not user.valid?
    assert_includes user.errors[:login_id], "is not a valid email address"
  end

  test "switching to username mode accepts a plain username and rejects email-only-invalid formats" do
    with_account_identifier("username") do
      valid_user = User.new(login_id: "taro.yamada", name: "Taro", password: "password")
      assert valid_user.valid?

      space_user = User.new(login_id: "a b", name: "Spacey", password: "password")
      assert_not space_user.valid?
      assert_includes space_user.errors[:login_id], "must be 3-32 characters using only lowercase letters, numbers, dots, underscores, or hyphens"

      short_user = User.new(login_id: "ab", name: "Too Short", password: "password")
      assert_not short_user.valid?
      assert_includes short_user.errors[:login_id], "must be 3-32 characters using only lowercase letters, numbers, dots, underscores, or hyphens"
    end
  end

  test "human_attribute_name for login_id follows identifier_mode" do
    assert_equal "Email", User.human_attribute_name(:login_id)

    with_account_identifier("username") do
      assert_equal "Username", User.human_attribute_name(:login_id)
    end
  end

  test "human_attribute_name for login_id follows identifier_mode in Japanese" do
    I18n.with_locale(:ja) do
      assert_equal "メールアドレス", User.human_attribute_name(:login_id)

      with_account_identifier("username") do
        assert_equal "ユーザー名", User.human_attribute_name(:login_id)
      end
    end
  end
end
