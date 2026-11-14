# Tells open screens that this record changed (see LiveUpdate). Runs after
# commit, for create, update and destroy alike (a destroyed record's
# attributes are still readable), and never breaks a save.
#
# A model says what changed by overriding:
#   live_update_dates   dates whose calendar day may look different, now and before
#   live_update_records "Model:id" keys of the records whose show page may change
#   live_update_all?    true when no date list can describe the change
module LiveUpdatable
  extend ActiveSupport::Concern

  # Date columns of a hospitalization that place it on the calendars.
  HOSPITALIZATION_DATE_COLUMNS = %i[ admission_date scheduled_admission_date scheduled_surgery_date scheduled_procedure_date discharge_date ].freeze

  included do
    after_commit :broadcast_live_update
  end

  def live_update_dates = []
  def live_update_records = []
  def live_update_all? = false

  private

    def broadcast_live_update
      LiveUpdate.broadcast(dates: live_update_dates, records: live_update_records, all: live_update_all?)
    rescue StandardError => e
      Rails.logger.error("LiveUpdate could not collect #{self.class.name}##{id}: #{e.class}: #{e.message}")
    end

    # The value of an attribute now and before the last save.
    def live_update_values(*attributes)
      attributes.flat_map { |attribute| [ public_send(attribute), attribute_before_last_save(attribute.to_s) ] }.uniq
    end

    def live_update_key(model, id)
      "#{model}:#{id}" if id
    end

    # Calendar dates of hospitalizations by id (one pluck).
    def live_update_hospitalization_dates(ids, columns: HOSPITALIZATION_DATE_COLUMNS)
      ids = ids.compact.uniq
      return [] if ids.empty?

      Hospitalization.where(id: ids).pluck(*columns).flatten
    end
end
