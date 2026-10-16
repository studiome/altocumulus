require "test_helper"

# The team select on the hospitalization / surgery forms and the team badge with
# the case-date members on their show pages; all of it only while
# features.teams is on.
class TeamAssignmentScreensTest < ActionDispatch::IntegrationTest
  setup do
    @config = { "features" => { "teams" => true } }
    @hospitalization = hospitalizations(:four)
    @surgery = surgeries(:three)
  end

  test "forms have no team select while the feature is off" do
    get edit_hospitalization_url(@hospitalization)
    assert_select "select[name='hospitalization[team_id]']", false
    get edit_surgery_url(@surgery)
    assert_select "select[name='surgery[team_id]']", false
  end

  test "forms offer active teams, plus the current inactive one, when the feature is on" do
    with_site_config(@config) do
      get edit_hospitalization_url(@hospitalization)
      assert_select "select[name='hospitalization[team_id]'] option", text: "Blue Team"
      assert_select "select[name='hospitalization[team_id]'] option", text: "Retired Team", count: 0

      @hospitalization.update_columns(team_id: teams(:retired_team).id)
      get edit_hospitalization_url(@hospitalization)
      assert_select "select[name='hospitalization[team_id]'] option[selected]", text: "Retired Team"

      get new_surgery_url
      assert_select "select[name='surgery[team_id]']"
    end
  end

  test "the team can be saved from the hospitalization and surgery forms" do
    with_site_config(@config) do
      patch hospitalization_url(@hospitalization), params: { hospitalization: { team_id: teams(:red).id } }
      assert_equal teams(:red), @hospitalization.reload.team
      patch surgery_url(@surgery), params: { surgery: { team_id: teams(:blue).id } }
      assert_equal teams(:blue), @surgery.reload.team
    end
  end

  test "team_id is ignored while the feature is off" do
    patch hospitalization_url(@hospitalization), params: { hospitalization: { team_id: teams(:red).id } }
    assert_nil @hospitalization.reload.team_id
  end

  test "forms offer an undecided option first after the blank one" do
    with_site_config(@config) do
      get edit_hospitalization_url(@hospitalization)
      assert_select "select[name='hospitalization[team_id]'] option:nth-child(2)[value='undecided']", text: I18n.t("teams.undecided")
      get new_surgery_url
      assert_select "select[name='surgery[team_id]'] option[value='undecided']"

      @hospitalization.update_columns(team_undecided: true)
      get edit_hospitalization_url(@hospitalization)
      assert_select "select[name='hospitalization[team_id]'] option[value='undecided'][selected]"
    end
  end

  test "undecided can be saved and satisfies a required team" do
    with_site_config(@config.merge("required_fields" => { "hospitalization" => [ "team_id" ] })) do
      patch hospitalization_url(@hospitalization), params: { hospitalization: { team_id: "undecided" } }
      assert_response :redirect
      assert @hospitalization.reload.team_undecided?
      assert_nil @hospitalization.team_id

      patch hospitalization_url(@hospitalization), params: { hospitalization: { team_id: teams(:red).id } }
      assert_not @hospitalization.reload.team_undecided?
    end
  end

  test "show pages display an undecided badge" do
    @hospitalization.update_columns(team_undecided: true)
    @surgery.update_columns(team_undecided: true)
    with_site_config(@config) do
      get hospitalization_url(@hospitalization)
      assert_select ".team-badge", text: I18n.t("teams.undecided_badge")
      get surgery_url(@surgery)
      assert_select ".team-badge", text: I18n.t("teams.undecided_badge")
    end
  end

  test "a required team shows an error when missing" do
    with_site_config(@config.merge("required_fields" => { "hospitalization" => [ "team_id" ] })) do
      patch hospitalization_url(@hospitalization), params: { hospitalization: { team_id: "" } }
      assert_response :unprocessable_entity
    end
  end

  test "show pages display the team badge and the members for the case date" do
    @surgery.update_columns(team_id: teams(:blue).id, surgery_date: Date.new(2026, 12, 10))
    @hospitalization.update_columns(team_id: teams(:blue).id, scheduled_admission_date: Date.new(2026, 10, 5))

    with_site_config(@config) do
      get surgery_url(@surgery)
      assert_select ".team-badge", text: "Blue Team"
      assert_select ".team-members", text: "Bravo(M), Alpha(S)"

      get hospitalization_url(@hospitalization)
      assert_select ".team-badge", text: "Blue Team"
      assert_select ".team-members", text: "Alpha(M), Bravo(S), Delta, Charlie"
    end
  end

  test "a surgery shows its hospitalization's team when it has none of its own" do
    @hospitalization.update_columns(team_id: teams(:red).id)
    @surgery.update_columns(hospitalization_id: @hospitalization.id, patient_id: @hospitalization.patient_id)
    with_site_config(@config) do
      get surgery_url(@surgery)
      assert_select ".team-badge", text: "Red Team"
    end
  end

  test "show pages show only the name when the date is undated, and nothing when the feature is off" do
    @surgery.update_columns(team_id: teams(:blue).id, surgery_date: nil)
    with_site_config(@config) do
      get surgery_url(@surgery)
      assert_select ".team-badge", text: "Blue Team"
      assert_select ".team-members", false
    end

    get surgery_url(@surgery)
    assert_select ".team-badge", false
  end
end
