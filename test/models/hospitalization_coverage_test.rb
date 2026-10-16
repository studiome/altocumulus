require "test_helper"

# The rule that decides which hospitalization a surgery date belongs to. It is
# shared by SurgeryReferralLookup and the backfill that links old surgeries, so
# it lives in one plain-Ruby module that works on anything period-shaped.
class HospitalizationCoverageTest < ActiveSupport::TestCase
  Period = HospitalizationCoverage::Period

  def period(start: nil, finish: nil, surgery: nil)
    Period.new(effective_admission_date: start, discharge_date: finish, scheduled_surgery_date: surgery)
  end

  test "covers a date inside the stay, bounds included" do
    stay = period(start: Date.new(2031, 5, 1), finish: Date.new(2031, 5, 5))
    assert HospitalizationCoverage.covers?(stay, Date.new(2031, 5, 1))
    assert HospitalizationCoverage.covers?(stay, Date.new(2031, 5, 3))
    assert HospitalizationCoverage.covers?(stay, Date.new(2031, 5, 5))
    assert_not HospitalizationCoverage.covers?(stay, Date.new(2031, 4, 30))
    assert_not HospitalizationCoverage.covers?(stay, Date.new(2031, 5, 6))
  end

  test "an open-ended stay covers every date from its start" do
    stay = period(start: Date.new(2031, 5, 1))
    assert HospitalizationCoverage.covers?(stay, Date.new(2032, 1, 1))
    assert_not HospitalizationCoverage.covers?(stay, Date.new(2031, 4, 30))
  end

  test "a stay with no start date covers nothing by period" do
    assert_not HospitalizationCoverage.covers?(period, Date.new(2031, 5, 1))
  end

  test "the scheduled surgery date covers regardless of the period" do
    stay = period(start: Date.new(2031, 5, 1), finish: Date.new(2031, 5, 2), surgery: Date.new(2031, 5, 9))
    assert HospitalizationCoverage.covers?(stay, Date.new(2031, 5, 9))
  end

  test "works on a Hospitalization record" do
    hospitalization = hospitalizations(:one)
    assert HospitalizationCoverage.covers?(hospitalization, hospitalization.admission_date)
    assert_not HospitalizationCoverage.covers?(hospitalization, hospitalization.discharge_date + 1)
  end
end
