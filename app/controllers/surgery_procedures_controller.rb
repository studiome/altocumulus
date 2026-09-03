class SurgeryProceduresController < ApplicationController
  before_action :set_surgery_procedure, only: %i[ show edit update destroy ]

  def index
    @surgery_procedures = SurgeryProcedure.alphabetical
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
        redirect_to @surgery_procedure, notice: "Surgery procedure was successfully created."
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
      redirect_to @surgery_procedure, notice: "Surgery procedure was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @surgery_procedure.destroy
      redirect_to surgery_procedures_path, notice: "Surgery procedure was successfully destroyed.", status: :see_other
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
end
