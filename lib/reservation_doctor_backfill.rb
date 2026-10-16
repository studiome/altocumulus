# Plain-SQL data half of the migration that turned hospitalizations'
# free-text reservation_doctor into a reference to a user. Like MasterBackfill
# it is free of application models and takes table/column names as arguments,
# so the migration keeps working however the models change later and a test can
# run it against scratch tables.
#
# A name is matched against users.name: first exactly (after stripping), then
# ignoring every whitespace character (including the full-width space). A name
# that fits no user, or more than one user, is left alone so a human can see
# the original text.
class ReservationDoctorBackfill
  def initialize(connection, table:, users_table:, string_column:, fk_column:)
    @connection = connection
    @table = table
    @users_table = users_table
    @string_column = string_column
    @fk_column = fk_column
  end

  # Links every unlinked row whose string identifies exactly one user and
  # clears that string (the user now carries the information). Returns
  # { matched:, unmatched: } counted over rows that had a non-blank string.
  def up
    users = connection.select_rows("SELECT id, name FROM #{u} WHERE name IS NOT NULL")
    exact = group_ids(users) { |name| name.strip }
    loose = group_ids(users) { |name| squash(name) }
    matched = unmatched = 0

    connection.select_rows(pending_rows_sql).each do |row_id, string|
      user_id = unique(exact[string.strip]) || unique(loose[squash(string)])
      if user_id
        connection.execute("UPDATE #{t} SET #{fk} = #{user_id.to_i}, #{str} = NULL WHERE id = #{row_id.to_i}")
        matched += 1
      else
        unmatched += 1
      end
    end

    { matched: matched, unmatched: unmatched }
  end

  # Writes each linked user's name back into the string column (rows whose
  # string is still set keep it).
  def down
    connection.execute(<<~SQL)
      UPDATE #{t} SET #{str} = (SELECT name FROM #{u} WHERE #{u}.id = #{t}.#{fk})
      WHERE #{fk} IS NOT NULL AND (#{str} IS NULL OR TRIM(#{str}) = '')
    SQL
  end

  private

    attr_reader :connection

    def t = connection.quote_table_name(@table)
    def u = connection.quote_table_name(@users_table)
    def str = connection.quote_column_name(@string_column)
    def fk = connection.quote_column_name(@fk_column)

    def pending_rows_sql
      "SELECT id, #{str} FROM #{t} WHERE #{fk} IS NULL AND #{str} IS NOT NULL AND TRIM(#{str}) <> '' ORDER BY id"
    end

    def squash(value)
      value.to_s.gsub(/[[:space:]]/, "")
    end

    def group_ids(users)
      users.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(id, name), groups|
        groups[yield(name)] << id
      end
    end

    # Only an unambiguous candidate counts.
    def unique(ids)
      ids.first if ids&.one?
    end
end
