require "test_helper"
require "support/master_record_model_tests"

class TeamTest < ActiveSupport::TestCase
  include MasterRecordModelTests

  def master_class = Team
  def used_fixture = teams(:blue)
  def unused_name = "Brand New Team"

  setup do
    hospitalizations(:one).update_columns(team_id: teams(:blue).id)
  end

  test "color must be one of the palette" do
    assert_equal %w[blue red green orange purple teal gray], Team::COLOR_KEYS
    team = Team.new(name: "X", color: "magenta")
    assert_not team.valid?
    assert team.errors.of_kind?(:color, :inclusion)
    Team::COLOR_KEYS.each { |key| assert Team.new(name: "X#{key}", color: key).valid? }
  end

  test "color labels are localized" do
    assert_equal "Blue", Team.color_options["blue"]
    assert_equal "青", I18n.with_locale(:ja) { Team.color_options["blue"] }
  end

  test "badge classes exist for every color" do
    Team::COLOR_KEYS.each { |key| assert Team.new(color: key).badge_class.present? }
  end

  test "a team referenced by a surgery cannot be destroyed" do
    surgeries(:one).update_columns(team_id: teams(:red).id)
    assert_not teams(:red).destroy
  end

  test "destroying an unused team removes its terms and members" do
    team = teams(:retired_team)
    term = team.team_terms.create!(starts_on: "2026-01-01", ends_on: "2026-02-28",
                                   team_term_members_attributes: [ { name: "Zed", role: "main" } ])
    assert_difference [ "TeamTerm.count", "TeamTermMember.count" ], -1 do
      team.destroy
    end
    assert_not TeamTerm.exists?(term.id)
  end

  test "term_for finds the term covering the date, inclusive at both ends" do
    team = teams(:blue)
    assert_equal term = team_terms(:blue_autumn), team.term_for(Date.new(2026, 10, 1))
    assert_equal term, team.term_for(Date.new(2026, 11, 30))
    assert_equal team_terms(:blue_winter), team.term_for(Date.new(2026, 12, 1))
    assert_nil team.term_for(Date.new(2026, 9, 30))
    assert_nil team.term_for(nil)
  end
end
