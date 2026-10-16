require "test_helper"

# The data half of the migration that turned surgeries.target_department /
# location strings into foreign keys. The real surgeries columns are gone by
# now, so it runs against a scratch table with the same shape.
class MasterBackfillTest < ActiveSupport::TestCase
  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table(:backfill_rows, force: true) do |t|
      t.string :label
      t.integer :master_id
    end
    @connection.create_table(:backfill_masters, force: true) do |t|
      t.string :name, null: false
      t.integer :position, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    @connection.add_index :backfill_masters, :name, unique: true
    @backfill = MasterBackfill.new(@connection, table: :backfill_rows, string_column: :label,
                                   fk_column: :master_id, master_table: :backfill_masters)
  end

  teardown do
    @connection.drop_table(:backfill_rows, if_exists: true)
    @connection.drop_table(:backfill_masters, if_exists: true)
  end

  def insert_rows(*labels)
    labels.each { |label| @connection.execute("INSERT INTO backfill_rows (label) VALUES (#{@connection.quote(label)})") }
  end

  def masters = @connection.select_rows("SELECT name, position, active FROM backfill_masters ORDER BY position")
  def row_labels = @connection.select_values("SELECT label FROM backfill_rows ORDER BY id")

  def linked_names
    @connection.select_values(<<~SQL)
      SELECT m.name FROM backfill_rows r LEFT JOIN backfill_masters m ON m.id = r.master_id ORDER BY r.id
    SQL
  end

  test "up creates one master per distinct trimmed string and links every row" do
    insert_rows("Cath Lab", " Cath Lab ", "Ward", nil, "", "   ", "Cath Lab")

    @backfill.up

    assert_equal [ [ "Cath Lab", 1, 1 ], [ "Ward", 2, 1 ] ], masters
    assert_equal [ "Cath Lab", "Cath Lab", "Ward", nil, nil, nil, "Cath Lab" ], linked_names
  end

  test "up reuses an existing master with the same name" do
    now = Time.current.to_fs(:db)
    @connection.execute("INSERT INTO backfill_masters (name, position, active, created_at, updated_at) VALUES ('Ward', 5, 0, '#{now}', '#{now}')")
    insert_rows("Ward", "New Room")

    @backfill.up

    assert_equal [ [ "Ward", 5, 0 ], [ "New Room", 6, 1 ] ], masters
    assert_equal [ "Ward", "New Room" ], linked_names
  end

  test "up with no data does nothing" do
    @backfill.up
    assert_empty masters
  end

  test "down restores the strings from the master names" do
    insert_rows("Cath Lab", "Ward", nil)
    @backfill.up
    @connection.execute("UPDATE backfill_rows SET label = NULL")

    @backfill.down

    assert_equal [ "Cath Lab", "Ward", nil ], row_labels
  end

  test "down then up is a round trip" do
    insert_rows("A", "B", "A")
    @backfill.up
    @backfill.down
    @connection.execute("UPDATE backfill_rows SET master_id = NULL")
    @backfill.up

    assert_equal %w[A B A], linked_names
    assert_equal 2, masters.size
  end
end
