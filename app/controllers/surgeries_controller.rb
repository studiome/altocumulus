class SurgeriesController < ApplicationController
  before_action :set_surgery, only: %i[ show edit update destroy ]
  before_action :set_form_collections, only: %i[ new edit create update ]

  def index
    @surgeries = Surgery.includes(:patient, { patient_diagnoses: :diagnosis }, { surgery_procedure_selections: :surgery_procedure }).order(surgery_date: :desc, created_at: :desc)
  end

  def show
  end

  def new
    @surgery = Surgery.new(patient_id: params[:patient_id])
    build_surgery_procedure_selections
  end

  def edit
    build_surgery_procedure_selections
  end

  def create
    @surgery = Surgery.new(surgery_params)

    respond_to do |format|
      if @surgery.save
        format.html { redirect_to @surgery, notice: "Surgery was successfully created." }
        format.json { render :show, status: :created, location: @surgery }
      else
        build_surgery_procedure_selections if @surgery.surgery_procedure_selections.empty?
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @surgery.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @surgery.update(surgery_params)
        format.html { redirect_to @surgery, notice: "Surgery was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @surgery }
      else
        build_surgery_procedure_selections if @surgery.surgery_procedure_selections.empty?
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @surgery.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    respond_to do |format|
      if @surgery.destroy
        format.html { redirect_to surgeries_path, notice: "Surgery was successfully destroyed.", status: :see_other }
        format.json { head :no_content }
      else
        format.html { redirect_to @surgery, alert: @surgery.errors.full_messages.to_sentence, status: :see_other }
        format.json { render json: @surgery.errors, status: :unprocessable_entity }
      end
    end
  end

  private

    def set_surgery
      @surgery = Surgery.find(params.expect(:id))
    end

    def set_form_collections
      @patients = Patient.order(:id)
      @patient_diagnoses = PatientDiagnosis.includes(:patient, :diagnosis).recent_first
      @surgery_procedures = SurgeryProcedure.alphabetical
    end

    def build_surgery_procedure_selections
      @surgery.surgery_procedure_selections.build if @surgery.surgery_procedure_selections.empty?
    end

    def surgery_params
      params.expect(surgery: [
        :surgery_date, :duration_hours, :anesthesia_method, :patient_id,
        { patient_diagnosis_ids: [] },
        { surgery_procedure_selections_attributes: [ [ :id, :surgery_procedure_id, :laterality, :_destroy ] ] }
      ])
    end
end
