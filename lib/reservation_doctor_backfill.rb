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
    exact = group_ids(users) { |name| name.strip }
    loose = group_ids(users) { |name| squash(name) }
    matched = unmatched = 0

    connection.select_rows(pending_rows).each do |row_id, string|
      user_id = unique(exact[string.strip]) || unique(loose[squash(string)])
      if user_id
        update = Arel::UpdateManager.new
        update.table(rows)
        update.set([ [ rows[@fk_column], user_id ], [ rows[@string_column], nil ] ])
        update.where(rows[:id].eq(row_id))
        connection.update(update)
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
    name_of_user = user_table.project(user_table[:name]).where(user_table[:id].eq(rows[@fk_column]))
    update = Arel::UpdateManager.new
    update.table(rows)
    update.set([ [ rows[@string_column], Arel::Nodes::Grouping.new(name_of_user.ast) ] ])
    update.where(rows[@fk_column].not_eq(nil).and(rows[@string_column].eq(nil).or(trimmed_string.eq(""))))
    connection.update(update)
  end

  private

    attr_reader :connection

    def rows = (@rows ||= Arel::Table.new(@table))
    def user_table = (@user_table ||= Arel::Table.new(@users_table))
    def trimmed_string = Arel::Nodes::NamedFunction.new("TRIM", [ rows[@string_column] ])

    def users
      connection.select_rows(user_table.project(user_table[:id], user_table[:name]).where(user_table[:name].not_eq(nil)))
    end

    def pending_rows
      rows.project(rows[:id], rows[@string_column])
          .where(rows[@fk_column].eq(nil))
          .where(rows[@string_column].not_eq(nil))
          .where(trimmed_string.not_eq(""))
          .order(rows[:id])
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
