require "test_helper"

class AdmissionCalendarTest < ActiveSupport::TestCase
  setup do
    @patients = 3.times.map { |i| Patient.create!(hospital_id: "AC#{i}", name: "Cal #{i}", date_of_birth: "1980-01-01") }
  end

  def reserve(patient, scheduled: nil, admitted: nil)
    Hospitalization.create!(patient: patient, scheduled_admission_date: scheduled, admission_date: admitted,
                            purpose: "examination", reason: nil,
                            hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:appendicitis).id } ])
  end

  test "counts non-deleted hospitalizations on their effective admission date" do
    reserve(@patients[0], scheduled: "2026-11-10")
    reserve(@patients[1], scheduled: "2026-11-10")
    deleted = reserve(@patients[2], scheduled: "2026-11-10")
    deleted.discard!

    AdmissionThresholdRule.create!(day_of_week: Date.new(2026, 11, 10).wday, threshold: 1)
    AdmissionThresholdRule.create!(day_of_week: Date.new(2026, 11, 11).wday, threshold: 1)
    calendar = AdmissionCalendar.new(month: Date.new(2026, 11, 1))

    assert_equal 2, calendar.count_for(Date.new(2026, 11, 10))
    assert_equal 0, calendar.count_for(Date.new(2026, 11, 11))
    assert calendar.over_threshold?(Date.new(2026, 11, 10))
    assert_not calendar.over_threshold?(Date.new(2026, 11, 11))
  end

  test "an actual admission date replaces the scheduled one" do
    reserve(@patients[0], scheduled: "2026-11-10", admitted: "2026-11-12")
    calendar = AdmissionCalendar.new(month: Date.new(2026, 11, 1))

    assert_equal 0, calendar.count_for(Date.new(2026, 11, 10))
    assert_equal 1, calendar.count_for(Date.new(2026, 11, 12))
  end

  test "weeks run Sunday to Saturday and cover the month with its leading and trailing days" do
    calendar = AdmissionCalendar.new(month: Date.new(2026, 11, 15))

    assert_equal Date.new(2026, 11, 1), calendar.month
    assert_equal Date.new(2026, 11, 1), calendar.weeks.first.first # 2026-11-01 is a Sunday
    assert calendar.weeks.all? { |week| week.size == 7 && week.first.sunday? }
    assert_equal Date.new(2026, 11, 30), calendar.weeks.flatten.find { |d| d == Date.new(2026, 11, 30) }
    assert calendar.in_month?(Date.new(2026, 11, 30))
    assert_not calendar.in_month?(Date.new(2026, 12, 1))
  end

  test "neighbouring months" do
    calendar = AdmissionCalendar.new(month: Date.new(2026, 1, 20))
    assert_equal Date.new(2025, 12, 1), calendar.previous_month
    assert_equal Date.new(2026, 2, 1), calendar.next_month
  end

  test "counts for a whole month grid take one query" do
    reserve(@patients[0], scheduled: "2026-11-10")
    calendar = AdmissionCalendar.new(month: Date.new(2026, 11, 1))
    calendar.weeks # warm up non-count work
    assert_queries_count(1) { AdmissionCalendar.new(month: Date.new(2026, 11, 1)).count_for(Date.new(2026, 11, 10)) }
  end

  test "each day is compared with its own threshold" do
    monday = Date.new(2026, 11, 9)
    tuesday = Date.new(2026, 11, 10)
    3.times { |i| reserve(@patients[i], scheduled: monday.iso8601) }
    3.times { |i| reserve(@patients[i], scheduled: tuesday.iso8601) }
    AdmissionThresholdRule.create!(day_of_week: monday.wday, threshold: 2)

    calendar = AdmissionCalendar.new(month: Date.new(2026, 11, 1))

    assert calendar.over_threshold?(monday)
    assert_not calendar.over_threshold?(tuesday), "Tuesday falls back to the default"
    assert_equal 2, calendar.threshold_for(monday)
    assert_equal Rails.application.config.x.admission_warning_threshold, calendar.threshold_for(tuesday)
  end

  test "a date override beats the weekday rule" do
    monday = Date.new(2026, 11, 9)
    reserve(@patients[0], scheduled: monday.iso8601)
    AdmissionThresholdRule.create!(day_of_week: monday.wday, threshold: 5)
    Holiday.create!(date: monday, holiday: false, admission_threshold: 0)

    assert AdmissionCalendar.new(month: Date.new(2026, 11, 1)).over_threshold?(monday)
  end

  test "parse reads a month or a date string and falls back to the current month" do
    assert_equal Date.new(2026, 11, 1), AdmissionCalendar.parse_month("2026-11")
    assert_equal Date.new(2026, 11, 1), AdmissionCalendar.parse_month("2026-11-17")
    assert_equal Date.current.beginning_of_month, AdmissionCalendar.parse_month("junk")
    assert_equal Date.current.beginning_of_month, AdmissionCalendar.parse_month(nil)
    assert_equal Date.current.beginning_of_month, AdmissionCalendar.parse_month([ "2026-11" ])
  end

  test "count_on is a single date lookup" do
    reserve(@patients[0], scheduled: "2026-11-10")
    assert_equal 1, AdmissionCalendar.count_on(Date.new(2026, 11, 10))
    assert_equal 0, AdmissionCalendar.count_on(Date.new(2026, 11, 9))
  end
end
