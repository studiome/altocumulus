require "test_helper"

# The data half of the migration that turned hospitalizations.reservation_doctor
# (free text) into a reference to users. Runs against scratch tables so it keeps
# working however the real tables change later.
class ReservationDoctorBackfillTest < ActiveSupport::TestCase
  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table(:backfill_users, force: true) { |t| t.string :name }
    @connection.create_table(:backfill_hospitalizations, force: true) do |t|
      t.string :legacy_name
      t.integer :doctor_id
    end
    @backfill = ReservationDoctorBackfill.new(@connection, table: :backfill_hospitalizations, users_table: :backfill_users,
                                              string_column: :legacy_name, fk_column: :doctor_id)
  end

  teardown do
    @connection.drop_table(:backfill_hospitalizations, if_exists: true)
    @connection.drop_table(:backfill_users, if_exists: true)
  end

  def add_users(*names)
    names.map do |name|
      @connection.execute("INSERT INTO backfill_users (name) VALUES (#{@connection.quote(name)})")
      @connection.select_value("SELECT last_insert_rowid()")
    end
  end

  def add_rows(*names)
    names.each { |n| @connection.execute("INSERT INTO backfill_hospitalizations (legacy_name) VALUES (#{@connection.quote(n)})") }
  end

  def rows = @connection.select_rows("SELECT legacy_name, doctor_id FROM backfill_hospitalizations ORDER BY id")

  test "up links exact matches after stripping and clears the matched legacy name" do
    taro, = add_users("山田 太郎", "Alice Smith")
    add_rows(" 山田 太郎 ", "Alice Smith", "Nobody")

    result = @backfill.up

    assert_equal [ [ nil, taro ], [ nil, taro + 1 ], [ "Nobody", nil ] ], rows
    assert_equal({ matched: 2, unmatched: 1 }, result)
  end

  test "up also matches ignoring all whitespace, including the full-width space" do
    taro, = add_users("山田 太郎")
    add_rows("山田　太郎", "山田太郎", "山田  太郎")

    @backfill.up

    assert_equal [ [ nil, taro ], [ nil, taro ], [ nil, taro ] ], rows
  end

  test "an exact match wins over a whitespace-insensitive one" do
    spaced, joined = add_users("山田 太郎", "山田太郎")
    add_rows("山田太郎", "山田 太郎")

    @backfill.up

    assert_equal [ [ nil, joined ], [ nil, spaced ] ], rows
  end

  test "ambiguous names are left unmatched" do
    add_users("山田 太郎", "山田　太郎")
    add_rows("山田太郎")

    result = @backfill.up

    assert_equal [ [ "山田太郎", nil ] ], rows
    assert_equal({ matched: 0, unmatched: 1 }, result)
  end

  test "blank legacy names and rows that already have a user are ignored" do
    taro, alice = add_users("Taro", "Alice")
    add_rows(nil, "", "   ", "Taro")
    @connection.execute("UPDATE backfill_hospitalizations SET doctor_id = #{alice} WHERE legacy_name = 'Taro'")

    result = @backfill.up

    assert_equal [ [ nil, nil ], [ "", nil ], [ "   ", nil ], [ "Taro", alice ] ], rows
    assert_equal({ matched: 0, unmatched: 0 }, result)
    assert_not_nil taro
  end

  test "down writes the linked user's name back where the legacy name is empty" do
    taro, = add_users("Taro")
    add_rows(nil, "Kept")
    @connection.execute("UPDATE backfill_hospitalizations SET doctor_id = #{taro}")

    @backfill.down

    assert_equal [ [ "Taro", taro ], [ "Kept", taro ] ], rows
  end
end
