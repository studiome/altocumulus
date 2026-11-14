# The version of a record for the edit forms' overwrite guard, taken from the
# audit trail: every real change to a Surgery, Hospitalization or Patient (and
# to their join rows, see AuditsAssociatedChanges) writes an AuditEvent for the
# parent, and a save that changes nothing writes none. So the version is the
# highest AuditEvent id of the record (0 when it has none); no column, no
# migration. A form carries the version it was rendered with and the update
# compares it with the current one (see EditConflictGuard).
module EditVersion
  # Who changed the records since a token, and when (their latest change).
  Editor = Struct.new(:name, :at, keyword_init: true)

  # The version of one or more records (the highest over all of them), in a
  # single query. Unsaved records and nils are ignored.
  def self.for(*records)
    scope = scope_for(records)
    scope ? scope.maximum(:id).to_i : 0
  end

  # The people whose changes are newer than `token`, each listed once with the
  # time of their latest change, newest first. A change without a user (script,
  # console) is listed as nameless.
  def self.editors_since(token, *records)
    scope = scope_for(records)
    return [] unless scope

    events = scope.where("audit_events.id > ?", token.to_i).includes(:user).order(id: :desc).to_a
    events.group_by(&:user_id).values.map do |user_events|
      latest = user_events.first
      Editor.new(name: latest.user&.name, at: latest.created_at)
    end
  end

  def self.scope_for(records)
    conditions = records.compact.select(&:persisted?).uniq.map do |record|
      AuditEvent.where(auditable_type: record.class.base_class.name, auditable_id: record.id)
    end
    return if conditions.empty?

    conditions.reduce(:or)
  end
  private_class_method :scope_for
end
