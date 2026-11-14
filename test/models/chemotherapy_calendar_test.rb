require "test_helper"

class ChemotherapyCalendarTest < ActiveSupport::TestCase
  setup do
    @day = Date.new(2026, 5, 11)
    @one = hospitalizations(:one)
    @two = hospitalizations(:two)
    @three = hospitalizations(:three)
    @four = hospitalizations(:four)
    @one.update_columns(purpose: "chemotherapy", scheduled_procedure_date: @day, scheduled_admission_date: @day - 1, admission_date: nil, discharge_date: nil)
    @two.update_columns(purpose: "chemoradiotherapy", scheduled_procedure_date: nil, scheduled_admission_date: @day, admission_date: nil, discharge_date: nil)
    @three.update_columns(purpose: "examination", scheduled_procedure_date: @day, scheduled_admission_date: @day, admission_date: nil, discharge_date: nil)
    @four.update_columns(purpose: "other", scheduled_procedure_date: nil, scheduled_admission_date: @day, admission_date: nil, discharge_date: nil)
  end

  def chemotherapy(**options)
    ChemotherapyCalendar.build(start: @day.iso8601, days: 3, **options)
  end

  def examination(**options)
    ExaminationCalendar.build(start: @day.iso8601, days: 3, **options)
  end

  test "lists only chemotherapy and chemoradiotherapy admissions, grouped like the examination tab" do
    assert_equal [ @one, @two ], chemotherapy.hospitalizations_for(@day)
    @two.update_columns(scheduled_procedure_date: @day + 2)
    assert_equal [ @one ], chemotherapy.hospitalizations_for(@day)
    assert_equal [ @two ], chemotherapy.hospitalizations_for(@day + 2)
  end

  test "those purposes leave the examination tab and stay on the admission tab" do
    assert_equal [ @three, @four ], examination.hospitalizations_for(@day)
    admission = AdmissionLedgerCalendar.build(start: (@day - 1).iso8601, days: 4)
    ids = admission.dates.flat_map { |date| admission.hospitalizations_for(date) }.map(&:id)
    assert_equal [ @one, @two, @three, @four ].map(&:id).sort, ids.sort
  end

  test "uses the purposes constant of Hospitalization and its own view name and booking purpose" do
    assert_equal Hospitalization::PROTOCOL_PURPOSE_KEYS, ChemotherapyCalendar::PURPOSES
    assert_equal "chemotherapy", chemotherapy.view_key
    assert_equal "chemotherapy", chemotherapy.new_reservation_purpose
    assert_equal "examination", examination.view_key
  end

  test "excludes deleted records and dates outside the range" do
    @two.update_columns(deleted_at: Time.current)
    @four.update_columns(purpose: "chemotherapy", scheduled_procedure_date: @day + 10)
    assert_equal [ @one ], chemotherapy.dates.flat_map { |date| chemotherapy.hospitalizations_for(date) }
  end

  test "mine and team filters narrow the rows but not the admission count" do
    @one.update_columns(reservation_doctor_id: users(:member).id)
    filtered = chemotherapy(filter: CalendarFilter.new(user: users(:member), mine: true))
    assert_equal [ @one ], filtered.hospitalizations_for(@day)
    assert_equal 3, filtered.admission_count_for(@day)

    with_site_config("features" => { "teams" => true }) do
      @two.update_columns(team_id: teams(:blue).id)
      by_team = chemotherapy(filter: CalendarFilter.new(user: users(:member), team_id: teams(:blue).id.to_s))
      assert_equal [ @two ], by_team.hospitalizations_for(@day)
    end
  end

  test "reads its columns from ledger_columns.chemotherapy_calendar, defaulting to the examination columns plus the protocol" do
    default = LedgerColumn.default_keys(:examination_calendar)
    index = default.index(:diagnosis_procedure_name)
    expected = default.dup.insert(index + 1, :protocol)
    assert_equal expected, chemotherapy.columns.map(&:key)
    assert_equal :hospitalization, LedgerColumn.subject_for(:chemotherapy_calendar)

    config = { "ledger_columns" => { "chemotherapy_calendar" => %w[patient protocol] } }
    with_site_config(config) { assert_equal %i[patient protocol], chemotherapy.columns.map(&:key) }
  end

  test "the patient links to the reservation form" do
    assert_equal "/reservations/#{@one.id}/edit", chemotherapy.ledger_context.href_for(@one)
  end

  test "the query count does not depend on the number of rows" do
    @one.update_columns(chemotherapy_protocol_id: chemotherapy_protocols(:protocol_a).id)
    few = count_queries { render(chemotherapy) }
    @three.update_columns(purpose: "chemotherapy", scheduled_procedure_date: @day + 1, chemotherapy_protocol_id: chemotherapy_protocols(:protocol_a).id)
    @four.update_columns(purpose: "chemoradiotherapy", scheduled_procedure_date: @day + 2, chemotherapy_protocol_id: chemotherapy_protocols(:protocol_b).id)
    many = count_queries { render(chemotherapy) }
    assert_equal few, many
  end

  private

    def render(calendar)
      context = calendar.ledger_context
      calendar.dates.each do |date|
        calendar.hospitalizations_for(date).each { |h| calendar.columns.each { |c| c.cell(h, context).plain_text } }
      end
    end

    def count_queries
      count = 0
      counter = ->(_n, _s, _f, _i, payload) { count += 1 unless payload[:cached] || payload[:name] == "SCHEMA" }
      ActiveRecord::Base.lease_connection.materialize_transactions
      ActiveRecord::Base.uncached { ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield } }
      count
    end
end
