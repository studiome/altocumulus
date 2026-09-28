require "test_helper"

class UserRoleTest < ActiveSupport::TestCase
  setup do
    @member = users(:member)
  end

  test "role must be one of User::ROLES" do
    user_role = UserRole.new(user: @member, role: "superuser")
    assert_not user_role.valid?
    assert user_role.errors.of_kind?(:role, :inclusion)
  end

  test "accepts any key in User::ROLES" do
    User::ROLES.each do |key|
      user_role = UserRole.new(user: User.new(login_id: "role-#{key}@example.com", name: "Role"), role: key)
      assert user_role.valid?, "expected role #{key} to be valid: #{user_role.errors.full_messages}"
    end
  end

  test "role is unique per user" do
    duplicate = UserRole.new(user: @member, role: "user")
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:role, :taken)
  end

  test "the same role can be held by different users" do
    other = User.create!(login_id: "other-role@example.com", name: "Other", password: "password", roles: %w[admin])
    user_role = UserRole.new(user: other, role: "user")
    assert user_role.valid?
  end
end
