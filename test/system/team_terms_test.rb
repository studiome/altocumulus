require "application_system_test_case"

class TeamTermsTest < ApplicationSystemTestCase
  setup do
    @original_config = SiteConfig.current
    SiteConfig.current = SiteConfig.from_hash("features" => { "teams" => true })
  end

  teardown do
    SiteConfig.current = @original_config
  end

  test "member rows can be added and removed on a new term" do
    visit new_team_team_term_path(teams(:red))

    fill_in "Starts on", with: Date.new(2027, 4, 1)
    fill_in "Ends on", with: Date.new(2027, 5, 31)

    assert_selector "[data-team-term-member-fields-target='item']", count: 0
    click_on "Add Member"
    click_on "Add Member"
    click_on "Add Member"
    assert_selector "[data-team-term-member-fields-target='item']", count: 3

    rows = all("[data-team-term-member-fields-target='item']")
    within(rows[0]) do
      fill_in "Name", with: "Golf"
      select "Main", from: "Role"
    end
    within(rows[1]) do
      select "Member User", from: "User"
      assert_field "Name", with: "Member User"
      select "Sub", from: "Role"
    end
    within(rows[2]) { click_on "Remove" }
    assert_selector "[data-team-term-member-fields-target='item']", count: 2

    assert_difference "TeamTermMember.count", 2 do
      click_on "Create Team term"
      assert_text "Term was successfully created."
    end
    assert_text "Golf(M), Member User(S)"
  end

  test "an existing member can be removed and a new one added when editing" do
    term = team_terms(:blue_autumn)
    visit edit_team_team_term_path(teams(:blue), term)

    assert_selector "[data-team-term-member-fields-target='item']", count: 4
    within(all("[data-team-term-member-fields-target='item']").last) { click_on "Remove" }
    assert_selector "[data-team-term-member-fields-target='item']", count: 3
    click_on "Add Member"
    within(all("[data-team-term-member-fields-target='item']").last) do
      fill_in "Name", with: "Echo"
    end

    click_on "Update Team term"
    assert_text "Term was successfully updated."
    assert_text "Alpha(M), Bravo(S), Delta, Echo"
  end

  test "copy previous term opens the swapped next term for editing" do
    visit team_team_terms_path(teams(:blue))
    accept_confirm { click_on "Copy Previous Term" }

    assert_text "The next term was created from the previous one."
    assert_field "Starts on", with: "2027-02-01"
    assert_selector "[data-team-term-member-fields-target='item']", count: 2
  end
end
