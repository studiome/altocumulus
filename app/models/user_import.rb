require "csv"

# Bulk user registration from a CSV an administrator uploads on
# /admin/user_import/new.
#
# The CSV needs a header row with `login_id` and `password`; `name`, `role`
# and `locale` are optional and fall back to the login id / the defaults a
# manually created user gets. Rows are imported one by one rather than in a
# single transaction, so one bad line does not throw away the rest of the
# file -- what happened to every line is reported back instead.
#
# The form that posts here submits without Turbo: the result page is a plain
# 200 rather than a redirect (it is too big to carry through the session), and
# Turbo refuses to render one.
#
# A login id that already exists is skipped, never updated: silently
# overwriting a colleague's password from a stale spreadsheet is the one
# mistake this screen must not make.
class UserImport
  include ActiveModel::Model

  REQUIRED_HEADERS = %w[ login_id password ].freeze
  OPTIONAL_HEADERS = %w[ name role locale ].freeze
  # A guard against a mistyped file (an export of something else, a
  # multi-megabyte log) being parsed and inserted row by row.
  MAX_ROWS = 500
  MAX_FILE_SIZE = 1.megabyte
  # Excel on a Japanese system reads a BOM-less UTF-8 CSV as Shift_JIS and
  # renders mojibake, so the downloadable template leads with a BOM (which
  # #parse_table strips again on the way back in).
  UTF8_BOM = "\uFEFF".freeze

  # `line` is the line number the admin sees in their spreadsheet: the header
  # is line 1, so the first data row reports as line 2.
  Row = Struct.new(:line, :login_id, :status, :message, keyword_init: true)

  Result = Struct.new(:rows, keyword_init: true) do
    def created_count = count(:created)
    def skipped_count = count(:skipped)
    def failed_count  = count(:failed)
    def count(status) = rows.count { |row| row.status == status }
  end

  attr_accessor :file

  # The starting point offered on the import screen: the header row alone,
  # deliberately without example rows -- a filled-in template that still
  # carries the samples would register them as real users.
  def self.template_csv
    UTF8_BOM + CSV.generate_line(REQUIRED_HEADERS + OPTIONAL_HEADERS)
  end

  validate :file_is_a_readable_csv

  def run
    Result.new(rows: table.each_with_index.map { |row, index| import_row(row, index + 2) })
  end

  private

    def import_row(row, line)
      login_id = row["login_id"].to_s.strip

      if login_id.present? && User.exists?(login_id: login_id.downcase)
        return Row.new(line: line, login_id: login_id, status: :skipped, message: I18n.t("user_import.already_exists"))
      end

      user = build_user(row, login_id)

      if user.save
        Row.new(line: line, login_id: login_id, status: :created)
      else
        # The messages come from the model's own validations, which never
        # interpolate the password's value -- only its length requirement.
        Row.new(line: line, login_id: login_id, status: :failed, message: user.errors.full_messages.to_sentence)
      end
    end

    def build_user(row, login_id)
      password = row["password"].to_s

      User.new(
        login_id: login_id,
        password: password,
        password_confirmation: password,
        name: row["name"].presence || login_id,
        role: row["role"].presence || "user",
        locale: row["locale"].presence || I18n.default_locale.to_s,
        active: true
      )
    end

    def file_is_a_readable_csv
      return errors.add(:file, :blank) if file.blank?
      return errors.add(:file, :too_big, count: MAX_FILE_SIZE / 1.megabyte) if file_too_big?

      if table.nil?
        errors.add(:file, :unparsable)
      elsif (REQUIRED_HEADERS - table.headers.map { |header| header.to_s.strip }).any?
        errors.add(:file, :missing_headers, headers: REQUIRED_HEADERS.join(", "))
      elsif table.size > MAX_ROWS
        errors.add(:file, :too_many_rows, count: MAX_ROWS)
      end
    end

    def file_too_big?
      file.respond_to?(:size) && file.size.to_i > MAX_FILE_SIZE
    end

    def table
      return @table if defined?(@table)

      @table = parse_table
    end

    def parse_table
      contents = file.read.to_s.dup.force_encoding(Encoding::UTF_8)
                     .encode("utf-8", invalid: :replace, undef: :replace)
      # Excel on a Japanese system writes a byte order mark, which would
      # otherwise end up inside the first header's name.
      contents = contents.delete_prefix("\uFEFF")
      CSV.parse(contents, headers: true, header_converters: ->(header) { header.to_s.strip.downcase })
    rescue CSV::MalformedCSVError
      nil
    end
end
