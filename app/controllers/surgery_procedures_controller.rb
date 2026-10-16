class SurgeryProceduresController < ApplicationController
  # Masters are admin-only, except that any signed-in user may register a new
  # procedure from inside the picker modal turbo-frame while booking (see
  # require_admin_unless_modal).
  before_action :require_admin, except: %i[ index show picker new create ]
  before_action :require_admin_unless_modal, only: %i[ new create ]
  before_action :set_surgery_procedure, only: %i[ show edit update destroy ]

  def index
    @surgery_procedures = SurgeryProcedure.alphabetical
  end

  # GET /surgery_procedures/picker
  def picker
    @pagination = Pagination.new(SurgeryProcedure.filtered(**filter_params).alphabetical, page: params[:page])
    @surgery_procedures = @pagination.records
  end

  def show
  end

  def new
    @surgery_procedure = SurgeryProcedure.new
  end

  def edit
  end

  def create
    @surgery_procedure = SurgeryProcedure.new(surgery_procedure_params)

    if @surgery_procedure.save
      if turbo_frame_request?
        render :create, formats: :turbo_stream
      else
        redirect_to @surgery_procedure, notice: t(".success_notice")
      end
    else
      if turbo_frame_request?
        render :new, formats: :turbo_stream, status: :unprocessable_entity
      else
        render :new, formats: :html, status: :unprocessable_entity
      end
    end
  end

  def update
    if @surgery_procedure.update(surgery_procedure_params)
      redirect_to @surgery_procedure, notice: t(".success_notice"), status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @surgery_procedure.destroy
      redirect_to surgery_procedures_path, notice: t(".success_notice"), status: :see_other
    else
      redirect_to surgery_procedure_path(@surgery_procedure), alert: @surgery_procedure.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

    def set_surgery_procedure
      @surgery_procedure = SurgeryProcedure.find(params.expect(:id))
    end

    def surgery_procedure_params
      params.expect(surgery_procedure: [ :name ])
    end

    def filter_params
      params.permit(:keyword).to_h.symbolize_keys
    end
end
