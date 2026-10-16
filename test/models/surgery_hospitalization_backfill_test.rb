require "test_helper"

# The data half of the migration that links existing surgeries to the
# hospitalization they belong to. Runs against scratch tables with the same
# columns it reads, so it keeps working however the real tables change.
class SurgeryHospitalizationBackfillTest < ActiveSupport::TestCase
  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table(:backfill_surgeries, force: true) do |t|
      t.integer :patient_id
      t.date :surgery_date
      t.integer :hospitalization_id
    end
    @connection.create_table(:backfill_hospitalizations, force: true) do |t|
      t.integer :patient_id
      t.date :admission_date
      t.date :scheduled_admission_date
      t.date :scheduled_surgery_date
      t.date :discharge_date
      t.datetime :deleted_at
    end
    @backfill = SurgeryHospitalizationBackfill.new(@connection, surgeries_table: :backfill_surgeries,
                                                   hospitalizations_table: :backfill_hospitalizations,
                                                   fk_column: :hospitalization_id)
  end

  teardown do
    @connection.drop_table(:backfill_surgeries, if_exists: true)
    @connection.drop_table(:backfill_hospitalizations, if_exists: true)
  end

  def add_hospitalization(patient_id, **cols) = insert(:backfill_hospitalizations, { patient_id: patient_id }.merge(cols))
  def add_surgery(patient_id, date) = insert(:backfill_surgeries, patient_id: patient_id, surgery_date: date)

  def insert(table, cols)
    names = cols.keys.join(", ")
    values = cols.values.map { |v| @connection.quote(v) }.join(", ")
    @connection.execute("INSERT INTO #{table} (#{names}) VALUES (#{values})")
    @connection.select_value("SELECT last_insert_rowid()")
  end

  def links = @connection.select_values("SELECT hospitalization_id FROM backfill_surgeries ORDER BY id")

  test "links a surgery to the one active hospitalization covering its date" do
    h = add_hospitalization(1, admission_date: "2031-05-01", discharge_date: "2031-05-05")
    add_surgery(1, "2031-05-03")

    result = @backfill.up

    assert_equal [ h ], links
    assert_equal({ linked: 1, ambiguous: 0, unmatched: 0 }, result)
  end

  test "uses the scheduled admission date until the patient is admitted" do
    h = add_hospitalization(1, scheduled_admission_date: "2031-05-01")
    add_surgery(1, "2031-05-10")

    @backfill.up

    assert_equal [ h ], links
  end

  test "the scheduled surgery date also covers" do
    h = add_hospitalization(1, admission_date: "2031-05-01", discharge_date: "2031-05-02", scheduled_surgery_date: "2031-05-09")
    add_surgery(1, "2031-05-09")

    @backfill.up

    assert_equal [ h ], links
  end

  test "leaves a surgery unlinked when nothing covers it" do
    add_hospitalization(1, admission_date: "2031-05-01", discharge_date: "2031-05-05")
    add_surgery(1, "2031-06-01")
    add_surgery(2, "2031-05-03") # another patient's hospitalization never counts

    result = @backfill.up

    assert_equal [ nil, nil ], links
    assert_equal({ linked: 0, ambiguous: 0, unmatched: 2 }, result)
  end

  test "leaves a surgery unlinked when several hospitalizations cover it" do
    add_hospitalization(1, admission_date: "2031-05-01", discharge_date: "2031-05-05")
    add_hospitalization(1, admission_date: "2031-05-03")
    add_surgery(1, "2031-05-04")

    result = @backfill.up

    assert_equal [ nil ], links
    assert_equal({ linked: 0, ambiguous: 1, unmatched: 0 }, result)
  end

  test "ignores discarded hospitalizations, undated surgeries and surgeries that are already linked" do
    add_hospitalization(1, admission_date: "2031-05-01", deleted_at: "2031-05-02 00:00:00")
    keep = add_hospitalization(1, admission_date: "2031-07-01")
    add_surgery(1, "2031-05-03")
    add_surgery(1, nil)
    @connection.execute("INSERT INTO backfill_surgeries (patient_id, surgery_date, hospitalization_id) VALUES (1, '2031-07-02', 999)")

    result = @backfill.up

    assert_equal [ nil, nil, 999 ], links
    assert_equal({ linked: 0, ambiguous: 0, unmatched: 1 }, result)
    assert_not_nil keep
  end
end
