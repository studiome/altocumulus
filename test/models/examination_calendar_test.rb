require "test_helper"

class ExaminationCalendarTest < ActiveSupport::TestCase
  setup do
    @day = Date.new(2026, 5, 11)
    @one = hospitalizations(:one)
    @two = hospitalizations(:two)
    @one.update_columns(purpose: "examination", scheduled_procedure_date: @day, scheduled_admission_date: @day - 1, admission_date: nil, discharge_date: nil)
    @two.update_columns(purpose: "examination", scheduled_procedure_date: nil, scheduled_admission_date: @day, admission_date: nil, discharge_date: nil)
  end

  def calendar(**options)
    ExaminationCalendar.build(start: @day.iso8601, days: 3, **options)
  end

  test "shares the range rules of the operations calendar" do
    assert_equal 3, calendar.dates.size
    assert_raises(OperationsCalendar::InvalidRangeError) { ExaminationCalendar.build(start: "nope") }
    assert_raises(OperationsCalendar::InvalidRangeError) { ExaminationCalendar.build(days: 0) }
    assert_equal OperationsCalendar::DEFAULT_DAYS, ExaminationCalendar.build.days
  end

  test "groups non-surgery hospitalizations by procedure date, else admission date" do
    rows = calendar.hospitalizations_for(@day)
    assert_equal [ @one.id, @two.id ].sort, rows.map(&:id).sort
    assert_empty calendar.hospitalizations_for(@day + 1)
  end

  test "orders a day by admission date then id" do
    assert_equal [ @one, @two ], calendar.hospitalizations_for(@day)
  end

  test "excludes surgery purposes, deleted records and dates outside the range" do
    hospitalizations(:three).update_columns(purpose: "surgery", scheduled_procedure_date: @day)
    hospitalizations(:four).update_columns(purpose: "chemotherapy", scheduled_procedure_date: @day + 10)
    @two.update_columns(deleted_at: Time.current)
    assert_equal [ @one ], calendar.hospitalizations_for(@day)
    assert_equal [], calendar.dates.flat_map { |date| calendar.hospitalizations_for(date) } - [ @one ]
  end

  test "uses a procedure date over the admission date for grouping" do
    @two.update_columns(scheduled_procedure_date: @day + 2)
    assert_equal [ @two ], calendar.hospitalizations_for(@day + 2)
  end

  test "counts admissions per day by admission date" do
    assert_equal 1, calendar.admission_count_for(@day)
    assert_equal 0, calendar.admission_count_for(@day - 1)
  end

  test "reads its columns from ledger_columns.examination_calendar" do
    config = { "ledger_columns" => { "examination_calendar" => %w[patient purpose] } }
    with_site_config(config) { assert_equal %i[patient purpose], calendar.columns.map(&:key) }
  end

  test "mine narrows to the user's reservations" do
    @one.update_columns(reservation_doctor_id: users(:member).id)
    filtered = calendar(filter: CalendarFilter.new(user: users(:member), mine: true))
    assert_equal [ @one ], filtered.hospitalizations_for(@day)
  end

  test "the query count does not depend on the number of rows" do
    few = count_queries { render(calendar) }
    hospitalizations(:three).update_columns(purpose: "examination", scheduled_procedure_date: @day + 1)
    hospitalizations(:four).update_columns(purpose: "examination", scheduled_procedure_date: @day + 2)
    many = count_queries { render(calendar) }
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
