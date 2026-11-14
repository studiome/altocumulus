require "test_helper"

class AdmissionLedgerCalendarTest < ActiveSupport::TestCase
  setup do
    @day = Date.new(2026, 5, 11)
    @one = hospitalizations(:one)
    @two = hospitalizations(:two)
    @one.update_columns(purpose: "surgery", scheduled_admission_date: @day, admission_date: nil, discharge_date: nil)
    @two.update_columns(purpose: "examination", scheduled_procedure_date: @day + 2, scheduled_admission_date: @day, admission_date: nil, discharge_date: nil)
  end

  def calendar(**options)
    AdmissionLedgerCalendar.build(start: @day.iso8601, days: 3, **options)
  end

  test "shares the range rules of the operations calendar" do
    assert_equal 3, calendar.dates.size
    assert_raises(OperationsCalendar::InvalidRangeError) { AdmissionLedgerCalendar.build(start: "nope") }
    assert_raises(OperationsCalendar::InvalidRangeError) { AdmissionLedgerCalendar.build(days: 0) }
    assert_equal OperationsCalendar::DEFAULT_DAYS, AdmissionLedgerCalendar.build.days
  end

  test "lists every purpose by effective admission date, ignoring the procedure date" do
    assert_equal [ @one.id, @two.id ].sort, calendar.hospitalizations_for(@day).map(&:id).sort
    assert_empty calendar.hospitalizations_for(@day + 2)
  end

  test "an actual admission date replaces the scheduled one" do
    @two.update_columns(admission_date: @day + 1)
    assert_equal [ @two ], calendar.hospitalizations_for(@day + 1)
    assert_equal [ @one ], calendar.hospitalizations_for(@day)
  end

  test "includes chemotherapy and other purposes" do
    hospitalizations(:three).update_columns(purpose: "chemotherapy", scheduled_admission_date: @day, admission_date: nil)
    hospitalizations(:four).update_columns(purpose: "other", scheduled_admission_date: @day, admission_date: nil)
    assert_includes calendar.hospitalizations_for(@day).map(&:id), hospitalizations(:three).id
    assert_includes calendar.hospitalizations_for(@day).map(&:id), hospitalizations(:four).id
  end

  test "orders a day by purpose then id" do
    assert_equal [ @two, @one ], calendar.hospitalizations_for(@day)
  end

  test "excludes deleted records and dates outside the range" do
    @two.update_columns(deleted_at: Time.current)
    hospitalizations(:three).update_columns(scheduled_admission_date: @day + 10, admission_date: nil)
    assert_equal [ @one ], calendar.hospitalizations_for(@day)
  end

  test "the day count equals the count shown on the other tabs" do
    assert_equal 2, calendar.admission_count_for(@day)
    assert_equal Hospitalization.admission_counts_on(calendar.dates)[@day], calendar.admission_count_for(@day)
    assert_equal 0, calendar.admission_count_for(@day + 1)
  end

  test "the warning starts above the threshold" do
    assert_not calendar.admission_warning?(@day)
    with_threshold(1) { assert calendar(filter: CalendarFilter.none).admission_warning?(@day) }
  end

  test "reads its columns from ledger_columns.admission_calendar" do
    config = { "ledger_columns" => { "admission_calendar" => %w[patient purpose] } }
    with_site_config(config) { assert_equal %i[patient purpose], calendar.columns.map(&:key) }
  end

  test "mine narrows the rows but not the count" do
    @one.update_columns(reservation_doctor_id: users(:member).id)
    filtered = calendar(filter: CalendarFilter.new(user: users(:member), mine: true))
    assert_equal [ @one ], filtered.hospitalizations_for(@day)
    assert_equal 2, filtered.admission_count_for(@day)
  end

  test "the query count does not depend on the number of rows" do
    few = count_queries { render(calendar) }
    hospitalizations(:three).update_columns(scheduled_admission_date: @day + 1, admission_date: nil)
    hospitalizations(:four).update_columns(scheduled_admission_date: @day + 2, admission_date: nil)
    many = count_queries { render(calendar) }
    assert_equal few, many
  end

  test "the warning compares the day with its own threshold" do
    monday = Date.new(2026, 5, 11)
    [ hospitalizations(:three), hospitalizations(:four) ].each { |h| h.update_columns(purpose: "other", scheduled_admission_date: monday + 1, admission_date: nil) }
    AdmissionThresholdRule.create!(day_of_week: monday.wday, threshold: 1)
    board = calendar

    assert_equal 1, board.admission_threshold_for(monday)
    assert board.admission_warning?(monday)
    assert_not board.admission_warning?(monday + 1), "the next weekday uses the default"
    assert_equal Rails.application.config.x.admission_warning_threshold, board.admission_threshold_for(monday + 1)
    assert_not board.admission_threshold_overridden?(monday)
  end

  test "a per-date override wins and is marked" do
    monday = Date.new(2026, 5, 11)
    [ hospitalizations(:three), hospitalizations(:four) ].each { |h| h.update_columns(purpose: "other", scheduled_admission_date: monday + 1, admission_date: nil) }
    AdmissionThresholdRule.create!(day_of_week: monday.wday, threshold: 1)
    Holiday.create!(date: monday, holiday: false, admission_threshold: 10)
    board = calendar

    assert_equal 10, board.admission_threshold_for(monday)
    assert board.admission_threshold_overridden?(monday)
    assert_not board.admission_warning?(monday)
  end

  private

    def with_threshold(value)
      original = Rails.application.config.x.admission_warning_threshold
      Rails.application.config.x.admission_warning_threshold = value
      yield
    ensure
      Rails.application.config.x.admission_warning_threshold = original
    end

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
