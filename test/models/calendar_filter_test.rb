require "test_helper"

class CalendarFilterTest < ActiveSupport::TestCase
  setup do
    @member = users(:member)
    @date = Date.new(2026, 3, 3)
    @dates = [ @date ]
    @surgery = surgeries(:three)
    @hospitalization = hospitalizations(:one)
    @surgery.update_columns(hospitalization_id: @hospitalization.id)
  end

  def filter(**options)
    CalendarFilter.new(user: @member, **options)
  end

  test "is inactive without mine or a team" do
    assert_not filter.active?
    assert_nil filter.surgery_ids(@dates)
    assert_equal({}, filter.to_params)
  end

  test "from_params reads mine and a numeric team id, ignoring junk" do
    with_site_config("features" => { "teams" => true }) do
      filter = CalendarFilter.from_params({ mine: "1", team_id: teams(:blue).id.to_s }, user: @member)
      assert filter.mine?
      assert_equal teams(:blue).id, filter.team_id
      assert_equal({ mine: "1", team_id: teams(:blue).id }, filter.to_params)

      junk = CalendarFilter.from_params({ mine: "yes", team_id: [ "1" ] }, user: @member)
      assert_not junk.active?
    end
  end

  test "the team filter is ignored while the teams feature is off" do
    assert_not CalendarFilter.from_params({ team_id: teams(:blue).id.to_s }, user: @member).active?
  end

  test "mine matches the reservation doctor" do
    @hospitalization.update_columns(reservation_doctor_id: @member.id)
    assert_includes filter(mine: true).surgery_ids(@dates), @surgery.id
    assert_not_includes filter(mine: true).surgery_ids(@dates), surgeries(:four).id
  end

  test "mine matches the user who entered the reservation" do
    @hospitalization.update_columns(created_by_id: @member.id)
    assert_includes filter(mine: true).surgery_ids(@dates), @surgery.id
  end

  test "mine matches a surgery whose operator name contains the user's name" do
    @surgery.update_columns(operator_name: "Dr. Member User")
    assert_includes filter(mine: true).surgery_ids(@dates), @surgery.id
  end

  test "mine matches a member of the case's team term on the case date" do
    with_site_config("features" => { "teams" => true }) do
      # Charlie (member) sits in Blue Team's 2026-10-01..11-30 term.
      @surgery.update_columns(surgery_date: Date.new(2026, 10, 15), team_id: teams(:blue).id)
      ids = filter(mine: true).surgery_ids([ Date.new(2026, 10, 15) ])
      assert_includes ids, @surgery.id

      @surgery.update_columns(surgery_date: Date.new(2026, 12, 15))
      assert_not_includes filter(mine: true).surgery_ids([ Date.new(2026, 12, 15) ]), @surgery.id
    end
  end

  test "mine falls back to the hospitalization's team" do
    with_site_config("features" => { "teams" => true }) do
      @surgery.update_columns(surgery_date: Date.new(2026, 10, 15))
      @hospitalization.update_columns(team_id: teams(:blue).id)
      assert_includes filter(mine: true).surgery_ids([ Date.new(2026, 10, 15) ]), @surgery.id
    end
  end

  test "the team filter keeps cases of the effective team" do
    with_site_config("features" => { "teams" => true }) do
      @surgery.update_columns(team_id: teams(:red).id)
      assert_equal [ @surgery.id ], filter(team_id: teams(:red).id).surgery_ids(@dates).to_a
      assert_empty filter(team_id: teams(:blue).id).surgery_ids(@dates)

      @surgery.update_columns(team_id: nil)
      @hospitalization.update_columns(team_id: teams(:blue).id)
      assert_equal [ @surgery.id ], filter(team_id: teams(:blue).id).surgery_ids(@dates).to_a
    end
  end

  test "a name with LIKE wildcards does not match everything" do
    @member.update_columns(name: "%")
    assert_empty filter(mine: true).surgery_ids(@dates)
  end

  test "hospitalization scope applies mine and team" do
    with_site_config("features" => { "teams" => true }) do
      @hospitalization.update_columns(reservation_doctor_id: @member.id, team_id: teams(:red).id)
      scope = Hospitalization.active

      assert_equal [ @hospitalization.id ], filter(mine: true).apply_to_hospitalizations(scope).pluck(:id)
      assert_equal [ @hospitalization.id ], filter(team_id: teams(:red).id).apply_to_hospitalizations(scope).pluck(:id)
      assert_empty filter(mine: true, team_id: teams(:blue).id).apply_to_hospitalizations(scope)
    end
  end
end
