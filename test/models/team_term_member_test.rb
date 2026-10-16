require "test_helper"

class TeamTermMemberTest < ActiveSupport::TestCase
  setup do
    @term = team_terms(:blue_autumn)
  end

  test "name is required when no user is chosen" do
    member = @term.team_term_members.new(role: "member")
    assert_not member.valid?
    assert member.errors.of_kind?(:name, :blank)
  end

  test "a blank name defaults to the chosen user's name" do
    member = @term.team_term_members.new(user: users(:member), name: " ", role: "member")
    assert member.valid?
    assert_equal "Member User", member.name
  end

  test "an explicit name is kept when a user is chosen" do
    member = @term.team_term_members.new(user: users(:member), name: "Dr. M", role: "member")
    member.valid?
    assert_equal "Dr. M", member.name
  end

  test "role must be main, sub or member" do
    assert_equal %w[main sub member], TeamTermMember::ROLE_KEYS
    member = @term.team_term_members.new(name: "X", role: "boss")
    assert_not member.valid?
    assert member.errors.of_kind?(:role, :inclusion)
  end

  test "role labels and abbreviations are localized" do
    assert_equal "Main", TeamTermMember.role_options["main"]
    assert_equal "メイン", I18n.with_locale(:ja) { TeamTermMember.role_options["main"] }
    assert_equal "M", I18n.with_locale(:ja) { TeamTermMember.new(role: "main").role_abbreviation }
    assert_equal "S", TeamTermMember.new(role: "sub").role_abbreviation
    assert_equal "", TeamTermMember.new(role: "member").role_abbreviation
  end

  test "user is optional" do
    member = @term.team_term_members.new(name: "Name Only", role: "member")
    assert member.valid?
  end
end
