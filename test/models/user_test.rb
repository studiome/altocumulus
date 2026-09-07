require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @member = users(:member)
  end

  test "valid user is valid" do
    user = User.new(email: "new@example.com", name: "New User", password: "password", password_confirmation: "password")
    assert user.valid?
  end

  test "requires email" do
    user = User.new(name: "No Email", password: "password")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "requires name" do
    user = User.new(email: "noname@example.com", password: "password")
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "email is normalized and uniqueness ignores case and whitespace" do
    user = User.new(email: "  ADMIN@Example.com  ", name: "Dup", password: "password")
    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "email is stored downcased and stripped" do
    user = User.create!(email: "  Mixed@Example.com  ", name: "Mixed Case", password: "password")
    assert_equal "mixed@example.com", user.email
  end

  test "password must be at least 8 characters" do
    user = User.new(email: "short@example.com", name: "Short", password: "short12")
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "role must be user or admin" do
    user = User.new(email: "role@example.com", name: "Role", password: "password", role: "superuser")
    assert_not user.valid?
    assert_includes user.errors[:role], "is not included in the list"
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
    other_admin = User.create!(email: "other-admin@example.com", name: "Other Admin", password: "password", role: "admin")
    @admin.active = false
    assert @admin.valid?
    assert other_admin.persisted?
  end
end
