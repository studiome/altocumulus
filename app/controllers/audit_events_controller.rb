class AuditEventsController < ApplicationController
  def index
    scope = AuditEvent.filtered(**filter_params).recent_first
    @pagination = Pagination.new(scope, page: params[:page])
    @audit_events = @pagination.records
  end

  def show
    @audit_event = AuditEvent.find(params.expect(:id))
  end

  private

    def filter_params
      params.permit(:auditable_type, :action).to_h.symbolize_keys
    end
end
