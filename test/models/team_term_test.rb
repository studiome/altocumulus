require "test_helper"

class TeamTermTest < ActiveSupport::TestCase
  setup do
    @team = teams(:blue)
  end

  test "dates are required and ends_on must not precede starts_on" do
    term = @team.team_terms.new
    assert_not term.valid?
    assert term.errors.of_kind?(:starts_on, :blank)
    assert term.errors.of_kind?(:ends_on, :blank)

    term = @team.team_terms.new(starts_on: "2027-03-10", ends_on: "2027-03-09")
    assert_not term.valid?
    assert term.errors.of_kind?(:ends_on, :must_be_on_or_after_starts_on)

    assert @team.team_terms.new(starts_on: "2027-03-10", ends_on: "2027-03-10").valid?
  end

  test "terms of the same team must not overlap" do
    overlapping = @team.team_terms.new(starts_on: "2026-11-30", ends_on: "2026-12-15")
    assert_not overlapping.valid?
    assert overlapping.errors.of_kind?(:base, :overlaps_another_term)

    inside = @team.team_terms.new(starts_on: "2026-10-10", ends_on: "2026-10-20")
    assert_not inside.valid?

    enclosing = @team.team_terms.new(starts_on: "2026-09-01", ends_on: "2027-03-01")
    assert_not enclosing.valid?

    adjacent = @team.team_terms.new(starts_on: "2027-02-01", ends_on: "2027-03-31")
    assert adjacent.valid?
  end

  test "a term does not overlap itself on update, and other teams may share dates" do
    term = team_terms(:blue_autumn)
    term.ends_on = "2026-11-15"
    assert term.valid?

    other = teams(:red).team_terms.new(starts_on: "2026-10-01", ends_on: "2026-11-30")
    assert other.valid?
  end

  test "at most one main and one sub member" do
    term = team_terms(:blue_autumn)
    term.team_term_members.build(name: "Echo", role: "main")
    assert_not term.valid?
    assert term.errors.of_kind?(:team_term_members, :only_one_main)

    term = TeamTerm.find(term.id)
    term.team_term_members.build(name: "Echo", role: "sub")
    assert_not term.valid?
    assert term.errors.of_kind?(:team_term_members, :only_one_sub)

    term = TeamTerm.find(team_terms(:blue_autumn).id)
    term.team_term_members.build(name: "Echo", role: "member")
    assert term.valid?
  end

  test "members marked for destruction do not count toward the main/sub limit" do
    term = team_terms(:blue_autumn)
    term.team_term_members.find { |m| m.role == "main" }.mark_for_destruction
    term.team_term_members.build(name: "Echo", role: "main")
    assert term.valid?
  end

  test "members_display lists main, sub, then members by position" do
    assert_equal "Alpha(M), Bravo(S), Delta, Charlie", team_terms(:blue_autumn).members_display
    assert_equal "Bravo(M), Alpha(S)", team_terms(:blue_winter).members_display
  end

  test "members_display uses the localized separator and abbreviations" do
    I18n.with_locale(:ja) do
      assert_equal "Alpha(M)・Bravo(S)・Delta・Charlie", team_terms(:blue_autumn).members_display
    end
  end

  test "members_display is empty for a term without members" do
    assert_equal "", @team.team_terms.new.members_display
  end

  test "nested attributes ignore rows with neither name nor user" do
    term = @team.team_terms.create!(
      starts_on: "2027-02-01", ends_on: "2027-03-31",
      team_term_members_attributes: [
        { name: "", user_id: "", role: "member" },
        { name: "Foxtrot", role: "main" },
        { name: "", user_id: users(:member).id.to_s, role: "sub" }
      ]
    )
    assert_equal [ "Foxtrot", "Member User" ], term.team_term_members.map(&:name)
  end

  test "next_term_attributes continues the day after, same whole-month length, swapping main and sub" do
    copy = team_terms(:blue_autumn).build_successor
    assert_not copy.persisted?
    assert_equal Date.new(2026, 12, 1), copy.starts_on
    assert_equal Date.new(2027, 1, 31), copy.ends_on
    assert_equal "Bravo(M), Alpha(S), Delta, Charlie", copy.members_display
    assert_equal users(:member), copy.team_term_members.find { |m| m.name == "Charlie" }.user
  end

  test "build_successor keeps the day count for terms that are not whole months" do
    term = @team.team_terms.create!(starts_on: "2027-02-05", ends_on: "2027-02-14")
    copy = term.build_successor
    assert_equal Date.new(2027, 2, 15), copy.starts_on
    assert_equal Date.new(2027, 2, 24), copy.ends_on
  end
end
