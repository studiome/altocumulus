class SurgeryProceduresController < ApplicationController
  before_action :set_surgery_procedure, only: %i[ show edit update destroy ]

  def index
    @surgery_procedures = SurgeryProcedure.order(:name)
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

    respond_to do |format|
      if @surgery_procedure.save
        format.html { redirect_to @surgery_procedure, notice: "Surgery procedure was successfully created." }
        format.turbo_stream
      else
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
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
    @surgery_procedure.destroy!
    redirect_to surgery_procedures_path, notice: "Surgery procedure was successfully destroyed.", status: :see_other
  end

  private

    def set_surgery_procedure
      @surgery_procedure = SurgeryProcedure.find(params.expect(:id))
    end

    def surgery_procedure_params
      params.expect(surgery_procedure: [ :name ])
    end
end
