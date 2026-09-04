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

    # The filter field cannot be named "action": params[:action] is always the
    # routing action ("index"), and leaking it into query_parameters makes the
    # pagination links generate a URL for a non-existent audit_events#create.
    def filter_params
      permitted = params.permit(:auditable_type, :audit_action)
      { auditable_type: permitted[:auditable_type], action: permitted[:audit_action] }
    end
end
