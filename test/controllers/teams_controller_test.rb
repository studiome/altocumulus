require "test_helper"

class TeamsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @config = { "features" => { "teams" => true } }
  end

  test "the screens are not found while the teams feature is off" do
    get teams_url
    assert_response :not_found
    get new_team_url
    assert_response :not_found
    get team_team_terms_url(teams(:blue))
    assert_response :not_found
    assert_no_difference("Team.count") { post teams_url, params: { team: { name: "Nope" } } }
  end

  test "index lists teams in order with color badge and a terms link" do
    with_site_config(@config) do
      get teams_url
      assert_response :success
      assert_equal Team.ordered.map(&:name), css_select("tbody td.master-name").map { |node| node.children.first.text.strip }
      assert_select "a[href='#{team_team_terms_path(teams(:blue))}']"
      assert_select "span.badge", text: "Inactive"
    end
  end

  test "new offers the color palette" do
    with_site_config(@config) do
      get new_team_url
      assert_response :success
      assert_select "select[name='team[color]'] option", Team::COLOR_KEYS.size
    end
  end

  test "create, update and destroy" do
    with_site_config(@config) do
      assert_difference("Team.count") do
        post teams_url, params: { team: { name: "Green Team", color: "green", position: 9, active: "1" } }
      end
      assert_redirected_to teams_url
      team = Team.find_by!(name: "Green Team")
      assert_equal "green", team.color

      patch team_url(team), params: { team: { name: "Verde", color: "orange" } }
      assert_redirected_to teams_url
      assert_equal [ "Verde", "orange" ], team.reload.attributes.values_at("name", "color")

      assert_difference("Team.count", -1) { delete team_url(team) }
    end
  end

  test "an invalid color re-renders the form" do
    with_site_config(@config) do
      assert_no_difference("Team.count") do
        post teams_url, params: { team: { name: "Bad", color: "magenta" } }
      end
      assert_response :unprocessable_entity
    end
  end

  test "a team in use cannot be deleted" do
    hospitalizations(:one).update_columns(team_id: teams(:blue).id)
    with_site_config(@config) do
      assert_no_difference("Team.count") { delete team_url(teams(:blue)) }
      assert_redirected_to teams_url
      assert flash[:alert].present?
    end
  end

  test "the Masters nav links to teams only when the feature is on" do
    get root_path
    assert_select "a[href='#{teams_path}']", false

    with_site_config(@config) do
      get root_path
      assert_select "li.dropdown > ul.dropdown-content a[href='#{teams_path}']"
    end
  end
end
