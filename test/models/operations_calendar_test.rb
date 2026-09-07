require "test_helper"

class OperationsCalendarTest < ActiveSupport::TestCase
  test "defaults to a 50-day range starting 7 days ago" do
    calendar = OperationsCalendar.build

    assert_equal Date.current - 7, calendar.start_date
    assert_equal 50, calendar.days
    assert_equal 50, calendar.dates.size
    assert_equal Date.current - 7, calendar.dates.first
    assert_equal Date.current + 42, calendar.dates.last
  end

  test "honors an explicit start and days" do
    calendar = OperationsCalendar.build(start: "2026-01-01", days: 10)

    assert_equal Date.new(2026, 1, 1), calendar.start_date
    assert_equal 10, calendar.dates.size
    assert_equal Date.new(2026, 1, 10), calendar.dates.last
  end

  test "raises InvalidRangeError for an unparsable start date instead of raising Date::Error" do
    assert_raises(OperationsCalendar::InvalidRangeError) do
      OperationsCalendar.build(start: "not-a-date")
    end
  end

  test "raises InvalidRangeError for a non-numeric days value" do
    assert_raises(OperationsCalendar::InvalidRangeError) do
      OperationsCalendar.build(days: "abc")
    end
  end

  test "raises InvalidRangeError for a days value beyond MAX_DAYS" do
    assert_raises(OperationsCalendar::InvalidRangeError) do
      OperationsCalendar.build(days: OperationsCalendar::MAX_DAYS + 1)
    end
  end

  test "raises InvalidRangeError for a zero or negative days value" do
    assert_raises(OperationsCalendar::InvalidRangeError) do
      OperationsCalendar.build(days: 0)
    end
  end

  test "raises InvalidRangeError for a non-numeric days array param rather than erroring" do
    assert_raises(OperationsCalendar::InvalidRangeError) do
      OperationsCalendar.build(days: [ "10" ])
    end
  end

  test "admission_count_for excludes discarded hospitalizations" do
    date = Date.current + 5
    create_hospitalization(scheduled_admission_date: date)
    deleted = create_hospitalization(scheduled_admission_date: date)
    deleted.discard!

    calendar = OperationsCalendar.build(start: date - 1, days: 3)

    assert_equal 1, calendar.admission_count_for(date)
  end

  # The whole app treats effective_admission_date (actual if present,
  # otherwise scheduled) as the single canonical date of a hospitalization --
  # sorting, Hospitalization.filtered's date-range filter, and the overlap
  # validation all key off it. The calendar's admission count must follow the
  # same rule: one hospitalization contributes to exactly one day's count,
  # never two, even when the scheduled and actual dates differ.
  test "admission_count_for counts a hospitalization once, at its effective (actual) date, not its superseded scheduled date" do
    scheduled_date = Date.current + 5
    actual_date = Date.current + 6
    create_hospitalization(scheduled_admission_date: scheduled_date, admission_date: actual_date)

    calendar = OperationsCalendar.build(start: scheduled_date - 1, days: 5)

    assert_equal 0, calendar.admission_count_for(scheduled_date)
    assert_equal 1, calendar.admission_count_for(actual_date)
  end

  # This is the regression case: admitting a patient on exactly the day that
  # was scheduled (the ordinary, common case) must still count as one
  # admission for that day, not two.
  test "admission_count_for counts a hospitalization once when the actual admission date matches the scheduled date" do
    date = Date.current + 5
    create_hospitalization(scheduled_admission_date: date, admission_date: date)

    calendar = OperationsCalendar.build(start: date - 1, days: 3)

    assert_equal 1, calendar.admission_count_for(date)
  end

  test "admission_warning? is driven by the configured threshold" do
    date = Date.current + 5
    3.times { create_hospitalization(scheduled_admission_date: date) }

    default_calendar = OperationsCalendar.build(start: date - 1, days: 3)
    assert_not default_calendar.admission_warning?(date)

    with_admission_warning_threshold(2) do
      calendar = OperationsCalendar.build(start: date - 1, days: 3)
      assert calendar.admission_warning?(date)
    end
  end

  test "exceeding the admission threshold does not block saving a hospitalization for that date" do
    date = Date.current + 5

    with_admission_warning_threshold(1) do
      create_hospitalization(scheduled_admission_date: date)
      second = Hospitalization.new(
        patient: new_patient, scheduled_admission_date: date, reason: "r2",
        hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:appendicitis).id } ]
      )

      assert second.save, second.errors.full_messages.to_sentence

      calendar = OperationsCalendar.build(start: date - 1, days: 3)
      assert calendar.admission_warning?(date)
    end
  end

  test "a comment-only day does not stop elective slots and exposes its note" do
    tuesday = next_wday(2)
    Holiday.create!(date: tuesday, holiday: false, note: "Fire drill today")

    calendar = OperationsCalendar.build(start: tuesday, days: 1)
    usage = calendar.slot_usages[tuesday]

    assert usage.configured?
    assert_not usage.holiday?
    assert_equal "Fire drill today", usage.holiday.note
  end

  test "a closed holiday stops elective slots" do
    tuesday = next_wday(2)
    Holiday.create!(date: tuesday, holiday: true, name: "Special Closure")

    calendar = OperationsCalendar.build(start: tuesday, days: 1)
    usage = calendar.slot_usages[tuesday]

    assert_not usage.configured?
    assert usage.holiday?
  end

  test "waiting mirrors Hospitalization.active.waiting" do
    calendar = OperationsCalendar.build
    assert_equal Hospitalization.active.waiting.to_a.sort_by(&:id), calendar.waiting.to_a.sort_by(&:id)
  end

  test "unconfirmed mirrors Hospitalization.active.unconfirmed" do
    calendar = OperationsCalendar.build
    assert_equal Hospitalization.active.unconfirmed.to_a.sort_by(&:id), calendar.unconfirmed.to_a.sort_by(&:id)
  end

  test "recently_updated mirrors Hospitalization.active.recently_updated" do
    calendar = OperationsCalendar.build
    assert_equal Hospitalization.active.recently_updated.to_a.sort_by(&:id), calendar.recently_updated.to_a.sort_by(&:id)
  end

  test "referred mirrors Hospitalization.active.referred" do
    calendar = OperationsCalendar.build
    assert_equal Hospitalization.active.referred.to_a.sort_by(&:id), calendar.referred.to_a.sort_by(&:id)
  end

  test "upcoming excludes a soft-deleted hospitalization even though its date is in the future" do
    date = Date.current + 10
    deleted = create_hospitalization(scheduled_admission_date: date)
    deleted.discard!

    calendar = OperationsCalendar.build
    assert_not_includes calendar.upcoming, deleted
    assert_equal 0, calendar.admission_count_for(date)
  end

  test "undated_surgeries lists surgeries with no surgery_date" do
    calendar = OperationsCalendar.build
    assert_equal Surgery.undated.to_a.sort_by(&:id), calendar.undated_surgeries.to_a.sort_by(&:id)
  end

  test "purpose_groups covers every non-default purpose without hardcoding the list" do
    calendar = OperationsCalendar.build
    expected = Hospitalization::PURPOSE_OPTIONS.keys - [ Hospitalization.column_defaults["purpose"] ]
    assert_equal expected.sort, calendar.purpose_groups.keys.sort
  end

  test "purpose_groups groups active hospitalizations by purpose" do
    date = Date.current + 3
    exam = create_hospitalization(scheduled_admission_date: date, purpose: "examination")

    calendar = OperationsCalendar.build
    assert_includes calendar.purpose_groups["examination"], exam
    assert_not_includes calendar.purpose_groups["chemotherapy"], exam
  end

  test "outside_regular_day_surgeries lists elective surgeries on a weekday with no ElectiveSlotRule" do
    # 2026-03-01 is a Sunday; the fixtures only configure rules for Tue/Wed/Fri.
    calendar = OperationsCalendar.build(start: Date.new(2026, 3, 1), days: 1)

    assert_includes calendar.outside_regular_day_surgeries.map(&:last), surgeries(:one)
  end

  test "outside_regular_day_surgeries excludes days that do have a configured rule" do
    calendar = OperationsCalendar.build(start: Date.new(2026, 3, 3), days: 1)

    assert_empty calendar.outside_regular_day_surgeries
  end

  test "announcements only include published ones" do
    calendar = OperationsCalendar.build
    assert_includes calendar.announcements, announcements(:published_one)
    assert_not_includes calendar.announcements, announcements(:draft_one)
  end

  test "issues a fixed number of queries regardless of the number of days" do
    small_count = count_queries { OperationsCalendar.build(days: 10) }
    large_count = count_queries { OperationsCalendar.build(days: 100) }

    assert_equal small_count, large_count
  end

  private

    # A fresh, hospitalization-free patient, so a new reservation can never
    # collide with the no-overlapping-period validation against fixture data
    # (patients(:one) carries an open-ended fixture hospitalization that
    # would conflict with almost any future date).
    def new_patient
      @patient_sequence = (@patient_sequence || 0) + 1
      Patient.create!(
        name: "Calendar Test Patient #{@patient_sequence}", hospital_id: "CAL#{@patient_sequence}",
        date_of_birth: Date.new(1980, 1, 1)
      )
    end

    def create_hospitalization(**attrs)
      Hospitalization.create!(
        {
          patient: new_patient, reason: "Calendar test reservation",
          hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:appendicitis).id } ]
        }.merge(attrs)
      )
    end

    def with_admission_warning_threshold(value)
      original = Rails.application.config.x.admission_warning_threshold
      Rails.application.config.x.admission_warning_threshold = value
      yield
    ensure
      Rails.application.config.x.admission_warning_threshold = original
    end

    # The first date on/after Date.current that falls on the given wday
    # (0 = Sunday), so tests don't depend on which real-world day they run on.
    def next_wday(wday)
      offset = (wday - Date.current.wday) % 7
      Date.current + offset
    end

    # Query-cache-disabled so that two sequential builds in the same test are
    # counted independently: without this, a second call's parameter-free
    # queries (the summary scopes, which are byte-identical SQL both times)
    # would come back as cache hits and silently under-count.
    def count_queries
      count = 0
      counter = ->(_name, _started, _finished, _unique_id, payload) do
        count += 1 unless payload[:cached] || payload[:name] == "SCHEMA"
      end

      ActiveRecord::Base.lease_connection.materialize_transactions
      ActiveRecord::Base.uncached do
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
      end
      count
    end
end
