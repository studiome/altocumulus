# The signal behind live screens: "these dates and these records changed".
#
# It deliberately carries no rendered HTML and no patient data (names, ids of
# anything but "Model:id" keys), because what a screen shows depends on who
# looks at it (admin-only parts, the mine / team filters). Every open browser
# receives the same tiny signal over one global stream and re-fetches what it
# shows with its own session (see app/javascript/live_update.js).
#
# A broadcast failure must never break or roll back a save: it is logged only.
class LiveUpdate
  STREAM = "live_update".freeze

  def self.broadcast(dates: [], records: [], all: false)
    dates = Array(dates).compact.map { |date| date.respond_to?(:iso8601) ? date.iso8601 : date.to_s }.uniq.sort
    records = Array(records).compact.map(&:to_s).uniq
    return if dates.empty? && records.empty? && !all

    attributes = { action: "live_update" }
    attributes[:dates] = dates.join(" ") if dates.any?
    attributes[:records] = records.join(" ") if records.any?
    attributes[:all] = "true" if all
    html = ActionController::Base.helpers.tag.public_send(:"turbo-stream", "", **attributes)
    Turbo::StreamsChannel.broadcast_stream_to(STREAM, content: html)
  rescue StandardError => e
    Rails.logger.error("LiveUpdate broadcast failed: #{e.class}: #{e.message}")
  end

  # "Model:id" key of a record, as the screens' records values name them.
  def self.key(record)
    "#{record.class.base_class.name}:#{record.id}" if record&.id
  end
end
