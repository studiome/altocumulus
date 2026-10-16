# Plain-SQL data half of the migration that replaced a free-text column with a
# foreign key to a master table (surgeries.target_department -> department_id
# and surgeries.location -> surgery_location_id). It is deliberately free of
# application models, so the migration keeps working however those models
# change later, and it takes the table/column names as arguments so a test can
# run it against a scratch table.
class MasterBackfill
  def initialize(connection, table:, string_column:, fk_column:, master_table:)
    @connection = connection
    @table = table
    @string_column = string_column
    @fk_column = fk_column
    @master_table = master_table
  end

  # Find-or-create a master row per distinct trimmed, non-blank string (in the
  # order they first appear) and point every row at its master.
  def up
    distinct_strings.each do |name|
      next if master_id_for(name)

      insert_master(name)
    end

    execute <<~SQL
      UPDATE #{t} SET #{fk} = (SELECT id FROM #{m} WHERE #{m}.name = TRIM(#{t}.#{str}))
      WHERE #{str} IS NOT NULL AND TRIM(#{str}) <> ''
    SQL
  end

  # Write each linked master's name back into the string column.
  def down
    execute <<~SQL
      UPDATE #{t} SET #{str} = (SELECT name FROM #{m} WHERE #{m}.id = #{t}.#{fk})
      WHERE #{fk} IS NOT NULL
    SQL
  end

  private

    attr_reader :connection

    def master = Arel::Table.new(@master_table)
    def t = connection.quote_table_name(@table)
    def m = connection.quote_table_name(@master_table)
    def str = connection.quote_column_name(@string_column)
    def fk = connection.quote_column_name(@fk_column)

    def execute(sql)
      connection.execute(sql)
    end

    def distinct_strings
      rows = Arel::Table.new(@table)
      trimmed = Arel::Nodes::NamedFunction.new("TRIM", [ rows[@string_column] ])
      query = rows.project(trimmed).where(rows[@string_column].not_eq(nil)).where(trimmed.not_eq(""))
                  .group(trimmed).order(rows[:id].minimum)
      connection.select_values(query)
    end

    def master_id_for(name)
      connection.select_value(master.project(master[:id]).where(master[:name].eq(name)))
    end

    def insert_master(name)
      position = connection.select_value(master.project(Arel.sql("COALESCE(MAX(position), 0) + 1")))
      now = connection.quote(Time.current.utc.to_fs(:db))
      execute <<~SQL
        INSERT INTO #{m} (name, position, active, created_at, updated_at)
        VALUES (#{connection.quote(name)}, #{position.to_i}, #{connection.quote(true)}, #{now}, #{now})
      SQL
    end
end
