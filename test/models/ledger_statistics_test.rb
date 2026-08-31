require "test_helper"

class LedgerStatisticsTest < ActiveSupport::TestCase
  test "total_patients counts all patients regardless of year" do
    stats = LedgerStatistics.new(year: 2026)
    assert_equal Patient.count, stats.total_patients
  end

  test "current_inpatients_count counts hospitalizations still admitted" do
    stats = LedgerStatistics.new
    assert_equal Hospitalization.in_hospital.count, stats.current_inpatients_count
    assert_equal 1, stats.current_inpatients_count
  end

  test "surgeries_count and hospitalizations_count are scoped to the given year" do
    stats = LedgerStatistics.new(year: 2026)
    assert_equal 7, stats.surgeries_count
    assert_equal 3, stats.hospitalizations_count
  end

  test "surgeries_count and hospitalizations_count are 0 for a year with no data" do
    stats = LedgerStatistics.new(year: 1999)
    assert_equal 0, stats.surgeries_count
    assert_equal 0, stats.hospitalizations_count
  end

  test "average_length_of_stay averages discharged hospitalizations rounded to 1 decimal" do
    stats = LedgerStatistics.new(year: 2026)
    # one: 2026-03-01 -> 2026-03-06 => 6 days; two: 2026-03-05 -> 2026-03-08 => 4 days
    assert_equal 5.0, stats.average_length_of_stay
  end

  test "average_length_of_stay is nil when nothing has been discharged" do
    stats = LedgerStatistics.new(year: 1999)
    assert_nil stats.average_length_of_stay
  end

  test "monthly_surgery_counts zero-fills all 12 months of the given year" do
    stats = LedgerStatistics.new(year: 2026)
    counts = stats.monthly_surgery_counts

    assert_equal 12, counts.size
    assert_equal Date.new(2026, 1, 1), counts.keys.first
    assert_equal Date.new(2026, 12, 1), counts.keys.last
    assert_equal 7, counts[Date.new(2026, 3, 1)]
    assert_equal 0, counts[Date.new(2026, 1, 1)]
  end

  test "monthly_hospitalization_counts zero-fills all 12 months of the given year" do
    stats = LedgerStatistics.new(year: 2026)
    counts = stats.monthly_hospitalization_counts

    assert_equal 12, counts.size
    assert_equal 2, counts[Date.new(2026, 3, 1)]
    assert_equal 1, counts[Date.new(2026, 6, 1)]
    assert_equal 0, counts[Date.new(2026, 1, 1)]
  end

  test "monthly counts default to the trailing 12 months when year is nil" do
    travel_to Date.new(2026, 8, 31) do
      stats = LedgerStatistics.new
      counts = stats.monthly_surgery_counts

      assert_equal 12, counts.size
      assert_equal Date.new(2025, 9, 1), counts.keys.first
      assert_equal Date.new(2026, 8, 1), counts.keys.last
      assert_equal 7, counts[Date.new(2026, 3, 1)]
    end
  end

  test "top_procedures returns procedure usage counts in descending order" do
    stats = LedgerStatistics.new(year: 2026)
    top = stats.top_procedures(limit: 10)

    assert_equal [ "Appendectomy", 4 ], top.first
    assert_includes top, [ "Knee arthroscopy", 3 ]
  end

  test "top_procedures respects the limit" do
    stats = LedgerStatistics.new(year: 2026)
    assert_equal 1, stats.top_procedures(limit: 1).size
  end

  test "top_diagnoses counts only hospitalization diagnoses, not patient diagnoses" do
    stats = LedgerStatistics.new(year: 2026)
    top = stats.top_diagnoses(limit: 10).to_h

    assert_equal({ "Pneumonia" => 1, "Hypertension" => 1, "Updated Diagnosis" => 1, "Appendicitis" => 1 }, top)
  end

  test "anesthesia_breakdown groups surgeries by anesthesia method" do
    stats = LedgerStatistics.new(year: 2026)
    assert_equal({ "General" => 6, "Spinal" => 1 }, stats.anesthesia_breakdown.to_h)
  end

  test "scheduling_type_breakdown groups surgeries by human-readable scheduling type label" do
    stats = LedgerStatistics.new(year: 2026)
    assert_equal({ "Elective" => 6, "Emergency" => 1 }, stats.scheduling_type_breakdown.to_h)
  end

  test "outcome_breakdown groups discharged hospitalizations by human-readable outcome label" do
    stats = LedgerStatistics.new(year: 2026)
    assert_equal({ "Recovered" => 1, "Improved" => 1 }, stats.outcome_breakdown.to_h)
  end

  test "available_years lists distinct years from surgeries and hospitalizations, descending" do
    stats = LedgerStatistics.new
    assert_equal [ 2026 ], stats.available_years
  end
end
