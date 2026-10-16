require "test_helper"

class TeamTermsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team = teams(:blue)
    @config = { "features" => { "teams" => true } }
  end

  test "index lists the team's terms with their members" do
    with_site_config(@config) do
      get team_team_terms_url(@team)
      assert_response :success
      assert_select "tbody tr", 2
      assert_select "td", text: /Alpha\(M\), Bravo\(S\), Delta, Charlie/
      assert_select "form[action='#{copy_previous_team_team_terms_path(@team)}']"
    end
  end

  test "new renders a member row template and add button" do
    with_site_config(@config) do
      get new_team_team_term_url(@team)
      assert_response :success
      assert_select "[data-controller='team-term-member-fields']"
      assert_select "template[data-team-term-member-fields-target='template']"
      assert_select "input[name='team_term[starts_on]']"
    end
  end

  test "create with nested members" do
    with_site_config(@config) do
      assert_difference [ "TeamTerm.count" ], 1 do
        assert_difference "TeamTermMember.count", 3 do
          post team_team_terms_url(@team), params: { team_term: {
            starts_on: "2027-02-01", ends_on: "2027-03-31", note: "Spring",
            team_term_members_attributes: {
              "1" => { name: "Golf", user_id: "", role: "main" },
              "2" => { name: "", user_id: users(:member).id, role: "sub" },
              "3" => { name: "Hotel", user_id: "", role: "member" },
              "4" => { name: "", user_id: "", role: "member" }
            }
          } }
        end
      end
      term = @team.team_terms.find_by!(starts_on: "2027-02-01")
      assert_redirected_to team_team_terms_url(@team)
      assert_equal "Golf(M), Member User(S), Hotel", term.members_display
    end
  end

  test "create with an overlapping term re-renders with an error" do
    with_site_config(@config) do
      assert_no_difference("TeamTerm.count") do
        post team_team_terms_url(@team), params: { team_term: { starts_on: "2026-11-01", ends_on: "2026-12-10" } }
      end
      assert_response :unprocessable_entity
    end
  end

  test "update edits, adds and removes members" do
    term = team_terms(:blue_autumn)
    with_site_config(@config) do
      patch team_team_term_url(@team, term), params: { team_term: {
        note: "Changed",
        team_term_members_attributes: {
          "0" => { id: team_term_members(:autumn_delta).id, _destroy: "1" },
          "1" => { id: team_term_members(:autumn_main).id, name: "Alpha Prime", role: "main" },
          "1700000000000" => { name: "Echo", role: "member", _destroy: "0" }
        }
      } }
      assert_redirected_to team_team_terms_url(@team)
    end
    term.reload
    assert_equal "Changed", term.note
    assert_equal "Alpha Prime(M), Bravo(S), Charlie, Echo", term.members_display
  end

  test "edit shows existing members" do
    with_site_config(@config) do
      get edit_team_team_term_url(@team, team_terms(:blue_autumn))
      assert_response :success
      assert_select "input[name$='[name]'][value='Alpha']"
    end
  end

  test "destroy removes the term and its members" do
    with_site_config(@config) do
      assert_difference "TeamTerm.count", -1 do
        assert_difference "TeamTermMember.count", -4 do
          delete team_team_term_url(@team, team_terms(:blue_autumn))
        end
      end
      assert_redirected_to team_team_terms_url(@team)
    end
  end

  test "copy_previous creates the next term with main and sub swapped and opens it for editing" do
    with_site_config(@config) do
      assert_difference "TeamTerm.count", 1 do
        post copy_previous_team_team_terms_url(@team)
      end
      copy = @team.team_terms.order(:starts_on).last
      assert_equal Date.new(2027, 2, 1), copy.starts_on
      assert_equal Date.new(2027, 3, 31), copy.ends_on
      assert_equal "Alpha(M), Bravo(S)", copy.members_display
      assert_redirected_to edit_team_team_term_url(@team, copy)
    end
  end

  test "copy_previous with no terms redirects back with an alert" do
    with_site_config(@config) do
      assert_no_difference "TeamTerm.count" do
        post copy_previous_team_team_terms_url(teams(:red))
      end
      assert_redirected_to team_team_terms_url(teams(:red))
      assert flash[:alert].present?
    end
  end

  test "everything is not found while the feature is off" do
    get edit_team_team_term_url(@team, team_terms(:blue_autumn))
    assert_response :not_found
    assert_no_difference("TeamTerm.count") { post copy_previous_team_team_terms_url(@team) }
    assert_response :not_found
  end
end
