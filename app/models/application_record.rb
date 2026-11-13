class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Case-insensitive "contains" search over one or more columns.
  # `sanitize_sql_like` escapes with a backslash, and SQLite's LIKE only
  # honours an escape character when ESCAPE names it, so both go together:
  # `_`, `%` and `\` in the keyword match literally.
  #
  #     where(like_condition("patients.name", "patients.hospital_id"), pattern: like_pattern(keyword))
  def self.like_condition(*columns)
    columns.map { |column| "#{column} LIKE :pattern ESCAPE '\\'" }.join(" OR ")
  end

  def self.like_pattern(keyword)
    "%#{sanitize_sql_like(keyword.to_s)}%"
  end
end
