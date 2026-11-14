# Keeps a second save from silently overwriting the first. The edit forms carry
# the EditVersion their record had when rendered (`edit_version`); an update
# compares it with the current one inside the save's transaction:
#   - equal, or the field absent (JSON callers, older clients): save as usual;
#   - different and no `overwrite=1`: nothing is saved, @edit_conflict says who
#     changed the record since, and the caller re-renders the form with what
#     the user typed (status 422, which Turbo renders), with a fresh token so
#     yet another change in between warns again;
#   - `overwrite=1` ("Save anyway"): save as usual.
module EditConflictGuard
  extend ActiveSupport::Concern

  EditConflict = Struct.new(:editors, keyword_init: true)

  included do
    helper_method :edit_version_token
  end

  private

    # Runs the save (the block, which returns truthy when it saved) after the
    # version check, in one transaction. `on_conflict` re-applies the user's
    # input to the record so the form shows it again. Returns the block's
    # result; false on a conflict (see @edit_conflict).
    def guarded_save(*records, on_conflict: nil)
      @edit_conflict = nil
      saved = false
      ActiveRecord::Base.transaction do
        if stale_edit?(records)
          @edit_conflict = EditConflict.new(editors: EditVersion.editors_since(params[:edit_version], *records))
          on_conflict&.call
          raise ActiveRecord::Rollback
        end
        saved = yield
        # A save that failed validation left nothing behind; make sure of it
        # even when an inner transaction swallowed its own rollback.
        raise ActiveRecord::Rollback unless saved
      end
      @edit_version_token = params[:edit_version].presence if !saved && @edit_conflict.nil? && params[:overwrite].blank?
      saved
    end

    def stale_edit?(records)
      return false if params[:overwrite].present?
      return false unless params.key?(:edit_version)

      EditVersion.for(*records).to_s != params[:edit_version].to_s
    end

    # The token the re-rendered form carries: the one it was submitted with
    # after an ordinary validation failure (so a change made meanwhile is still
    # caught on the next submit), else the record's current version.
    def edit_version_token(*records)
      (@edit_version_token || EditVersion.for(*records)).to_s
    end

    def edit_failure_json(errors)
      if @edit_conflict
        render json: { error: "edit_conflict" }, status: :conflict
      else
        render json: errors, status: :unprocessable_entity
      end
    end
end
