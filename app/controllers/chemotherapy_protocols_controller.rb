# The protocol master. Like the other masters only administrators edit it,
# except that any signed-in user may look protocols up and register a new one
# from inside the picker modal turbo-frame while booking (see
# require_admin_unless_modal), as with surgery procedures. The standalone
# new/create screens, edit, update and destroy stay admin-only.
class ChemotherapyProtocolsController < MasterRecordsController
  skip_before_action :require_admin
  before_action :require_admin, except: %i[ index picker new create ], prepend: true
  before_action :require_admin_unless_modal, only: %i[ new create ], prepend: true

  # GET /chemotherapy_protocols/picker
  def picker
    scope = ChemotherapyProtocol.active.filtered(**filter_params).ordered
    @pagination = Pagination.new(scope, page: params[:page])
    @records = @pagination.records
  end

  def create
    return super unless turbo_frame_request?

    @record = ChemotherapyProtocol.new(record_params)
    if @record.save
      render :create, formats: :turbo_stream
    else
      render :new, formats: :turbo_stream, status: :unprocessable_entity
    end
  end

  private

    def master_class = ChemotherapyProtocol

    # A non-admin (the modal) only names the protocol: it starts active at the
    # next position.
    def record_params
      return super if admin?

      params.expect(chemotherapy_protocol: [ :name ])
    end

    def filter_params
      params.permit(:keyword).to_h.symbolize_keys
    end
end
