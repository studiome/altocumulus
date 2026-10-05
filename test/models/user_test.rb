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

  test "a new user defaults to the Japanese locale" do
    assert_equal "ja", User.new.locale
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

  test "roles= with an unknown key is invalid" do
    user = User.new(login_id: "role@example.com", name: "Role", password: "password", roles: %w[superuser])
    assert_not user.valid?
    assert user.errors.of_kind?(:roles, :inclusion)
    assert_includes user.errors[:roles], "is not included in the list"
  end

  test "accepts data_manager as a role" do
    user = User.new(login_id: "dm@example.com", name: "Data Manager", password: "password", roles: %w[data_manager])
    assert user.valid?
  end

  test "a user may hold multiple roles simultaneously" do
    user = User.new(login_id: "multi@example.com", name: "Multi", password: "password", roles: %w[admin data_manager])
    assert user.valid?
    assert user.admin?
    assert user.data_manager?
    assert_not user.user_role?
    assert_equal %w[data_manager admin], user.roles
  end

  test "roles= ignores blank entries from the collection_check_boxes hidden field" do
    user = User.new(login_id: "blankrole@example.com", name: "Blank", password: "password", roles: [ "", "admin" ])
    assert user.valid?
    assert user.admin?
  end

  test "roles= accepts string or symbol keys" do
    user = User.new(login_id: "symrole@example.com", name: "Sym", password: "password")
    user.roles = [ :admin, "data_manager" ]
    assert user.admin?
    assert user.data_manager?
  end

  test "no roles is invalid" do
    user = User.new(login_id: "noroles@example.com", name: "No Roles", password: "password", roles: [])
    assert_not user.valid?
    assert_includes user.errors[:roles], "can't be blank"
  end

  test "roles returns held role keys in ROLES order" do
    user = User.new(roles: %w[admin user])
    assert_equal %w[user admin], user.roles
  end

  test "a persisted new user defaults to the Japanese locale" do
    user = User.create!(login_id: "default-locale@example.com", name: "Default Locale", password: "password")
    assert_equal "ja", user.reload.locale
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
    assert_not users(:data_manager).admin?
  end

  # data_manager is a parallel flag alongside user/admin, so it carries no
  # admin privileges of its own (yet): only the predicate and the localized
  # label distinguish it.
  test "data_manager? reflects role" do
    assert users(:data_manager).data_manager?
    assert_not @admin.data_manager?
    assert_not @member.data_manager?
  end

  test "role_options covers every role and role_labels uses it" do
    assert_equal User::ROLES.sort, User.role_options.keys.sort
    assert_equal [ User.role_options["data_manager"] ], users(:data_manager).role_labels
  end

  test "active scope only returns active users" do
    assert_includes User.active, @admin
    assert_not_includes User.active, users(:inactive)
  end

  test "admins scope returns only users holding the admin role" do
    assert_includes User.admins, @admin
    assert_not_includes User.admins, @member
    assert_includes User.admins, users(:admin_data_manager)
  end

  test "with_role scope returns users holding the given role" do
    assert_includes User.with_role("data_manager"), users(:data_manager)
    assert_includes User.with_role("data_manager"), users(:admin_data_manager)
    assert_not_includes User.with_role("data_manager"), @member
  end

  test "a new user with no explicit roles defaults to user" do
    user = User.new(login_id: "default-role@example.com", name: "Default Role", password: "password")
    assert_equal %w[user], user.roles
  end

  test "roles= persists added and removed rows on save" do
    @member.roles = %w[admin data_manager]
    @member.save!
    assert_equal %w[data_manager admin], @member.reload.roles

    @member.roles = %w[user]
    @member.save!
    assert_equal %w[user], @member.reload.roles
    assert_equal 1, UserRole.where(user: @member).count
  end

  test "destroying a user destroys its user_roles" do
    user = User.create!(login_id: "destroy-me@example.com", name: "Destroy Me", password: "password", roles: %w[admin data_manager])
    assert_difference("UserRole.count", -2) do
      user.destroy
    end
  end

  test "cannot deactivate the last active admin" do
    User.admins.where.not(id: @admin.id).update_all(active: false)
    @admin.active = false
    assert_not @admin.valid?
    assert_includes @admin.errors[:base], "Cannot remove the last active admin"
  end

  test "cannot demote the last active admin" do
    User.admins.where.not(id: @admin.id).update_all(active: false)
    @admin.roles = %w[user]
    assert_not @admin.valid?
    assert_includes @admin.errors[:base], "Cannot remove the last active admin"
  end

  test "cannot remove admin role from the last active admin even while keeping other roles" do
    User.admins.where.not(id: users(:admin_data_manager).id).update_all(active: false)
    dual = users(:admin_data_manager)
    dual.roles = %w[data_manager]
    assert_not dual.valid?
    assert_includes dual.errors[:base], "Cannot remove the last active admin"
  end

  test "can deactivate an admin when another active admin remains" do
    other_admin = User.create!(login_id: "other-admin@example.com", name: "Other Admin", password: "password", roles: %w[admin])
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
