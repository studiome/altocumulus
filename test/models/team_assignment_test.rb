require "test_helper"

# Team assignment of hospitalizations and surgeries, and the members shown for
# the case date.
class TeamAssignmentTest < ActiveSupport::TestCase
  setup do
    @team = teams(:blue)
    @hospitalization = hospitalizations(:one)
  end

  test "a surgery created for a hospitalization defaults to its team" do
    @hospitalization.update!(team: @team)
    surgery = build_surgery(hospitalization: @hospitalization)
    surgery.save!
    assert_equal @team, surgery.team
  end

  test "a surgery with its own team keeps it" do
    @hospitalization.update!(team: @team)
    surgery = build_surgery(hospitalization: @hospitalization, team: teams(:red))
    surgery.save!
    assert_equal teams(:red), surgery.team
  end

  test "the default is only applied on create" do
    surgery = build_surgery(hospitalization: @hospitalization)
    surgery.save!
    @hospitalization.update!(team: @team)
    surgery.update!(anesthesia_method: "Spinal")
    assert_nil surgery.reload.team
  end

  test "effective_team is the own team, else the hospitalization's" do
    surgery = surgeries(:one)
    assert_nil surgery.effective_team

    surgery.hospitalization = @hospitalization
    @hospitalization.team = @team
    assert_equal @team, surgery.effective_team

    surgery.team = teams(:red)
    assert_equal teams(:red), surgery.effective_team
  end

  test "surgery members are those of the term covering the surgery date" do
    surgery = surgeries(:one)
    surgery.team = @team
    surgery.surgery_date = Date.new(2026, 10, 20)
    assert_equal team_terms(:blue_autumn), surgery.team_term
    assert_equal "Alpha(M), Bravo(S), Delta, Charlie", surgery.team_members_display

    surgery.surgery_date = Date.new(2026, 12, 20)
    assert_equal "Bravo(M), Alpha(S)", surgery.team_members_display
  end

  test "an undated case, or a date outside every term, shows no members" do
    surgery = surgeries(:one)
    surgery.team = @team
    surgery.surgery_date = nil
    assert_nil surgery.team_members_display

    surgery.surgery_date = Date.new(2030, 1, 1)
    assert_nil surgery.team_members_display
  end

  test "hospitalization uses the scheduled surgery date, then the procedure date, then the admission date" do
    hospitalization = hospitalizations(:four)
    hospitalization.team = @team
    hospitalization.scheduled_admission_date = Date.new(2026, 10, 5)
    hospitalization.scheduled_procedure_date = Date.new(2026, 12, 5)
    hospitalization.scheduled_surgery_date = Date.new(2026, 10, 10)
    assert_equal Date.new(2026, 10, 10), hospitalization.team_display_date

    hospitalization.scheduled_surgery_date = nil
    assert_equal Date.new(2026, 12, 5), hospitalization.team_display_date

    hospitalization.scheduled_procedure_date = nil
    assert_equal Date.new(2026, 10, 5), hospitalization.team_display_date
    assert_equal "Alpha(M), Bravo(S), Delta, Charlie", hospitalization.team_members_display

    hospitalization.admission_date = Date.new(2026, 12, 7)
    assert_equal Date.new(2026, 12, 7), hospitalization.team_display_date
  end

  test "required team_id in the site config applies to hospitalizations and surgeries" do
    with_site_config("features" => { "teams" => true },
                     "required_fields" => { "hospitalization" => [ "team_id" ], "surgery" => [ "team_id" ] }) do
      assert_not hospitalizations(:one).tap { |h| h.team = nil }.valid?
      assert_not surgeries(:one).valid?
      surgeries(:one).team = @team
      assert surgeries(:one).tap { |s| s.team = @team }.valid?
    end
  end

  # --- team undecided (チーム未決定) -----------------------------------------

  test "team_id accepts the undecided choice, which is no team" do
    hospitalization = hospitalizations(:one)
    hospitalization.team_id = "undecided"
    assert hospitalization.team_undecided?
    assert_nil hospitalization.team_id
    assert_equal "undecided", hospitalization.team_choice
  end

  test "choosing a team, or leaving it blank, clears undecided" do
    hospitalization = hospitalizations(:one)
    hospitalization.team_id = "undecided"
    hospitalization.team_id = @team.id.to_s
    assert_not hospitalization.team_undecided?

    hospitalization.team_id = "undecided"
    hospitalization.team_id = ""
    assert_not hospitalization.team_undecided?
    assert_nil hospitalization.team_choice

    hospitalization.team_undecided = true
    hospitalization.team = @team
    hospitalization.valid?
    assert_not hospitalization.team_undecided?
  end

  test "a required team is satisfied by undecided but not by leaving it blank" do
    config = { "features" => { "teams" => true },
               "required_fields" => { "hospitalization" => [ "team_id" ], "surgery" => [ "team_id" ] } }
    with_site_config(config) do
      hospitalization = hospitalizations(:one)
      hospitalization.team_id = ""
      assert_not hospitalization.valid?
      assert hospitalization.errors.added?(:team_id, :blank)

      hospitalization.team_id = "undecided"
      hospitalization.valid?
      assert_not hospitalization.errors.added?(:team_id, :blank)

      surgery = surgeries(:one)
      surgery.team_id = ""
      assert_not surgery.valid?
      surgery.team_id = "undecided"
      surgery.valid?
      assert_not surgery.errors.added?(:team_id, :blank)
    end
  end

  test "a surgery created for an undecided hospitalization is undecided too" do
    @hospitalization.update!(team_undecided: true)
    surgery = build_surgery(hospitalization: @hospitalization)
    surgery.save!
    assert surgery.team_undecided?
    assert surgery.effective_team_undecided?
  end

  test "effective_team_undecided? follows the hospitalization only while the surgery has no team of its own" do
    surgery = surgeries(:one)
    surgery.hospitalization = @hospitalization
    @hospitalization.team_undecided = true
    assert surgery.effective_team_undecided?

    surgery.team = @team
    assert_not surgery.effective_team_undecided?

    @hospitalization.team_undecided = false
    @hospitalization.team = @team
    surgery.team = nil
    surgery.team_undecided = true
    assert surgery.effective_team_undecided?
    assert_nil surgery.effective_team, "an explicit undecided on the surgery beats the hospitalization's team"
    assert_not @hospitalization.effective_team_undecided?
  end

  private

    def build_surgery(**attributes)
      surgery = Surgery.new(patient: patients(:one), surgery_date: Date.new(2026, 10, 20),
                            anesthesia_method: "General", **attributes)
      surgery.surgery_procedure_selections.build(surgery_procedure: surgery_procedures(:appendectomy))
      surgery
    end
end
