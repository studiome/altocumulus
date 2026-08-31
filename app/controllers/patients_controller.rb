class PatientsController < ApplicationController
  before_action :set_patient, only: %i[ show edit update destroy ]

  # GET /patients or /patients.json
  def index
    @pagination = Pagination.new(Patient.filtered(**filter_params).ordered, page: params[:page])
    @patients = @pagination.records
  end

  # GET /patients/1 or /patients/1.json
  def show
    @patient_diagnoses = @patient.patient_diagnoses.includes(:diagnosis).recent_first
  end

  # GET /patients/new
  def new
    @patient = Patient.new
  end

  # GET /patients/1/edit
  def edit
  end

  # POST /patients or /patients.json
  def create
    @patient = Patient.new(patient_params)

    respond_to do |format|
      if @patient.save
        format.html { redirect_to @patient, notice: "Patient was successfully created." }
        format.json { render :show, status: :created, location: @patient }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @patient.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /patients/1 or /patients/1.json
  def update
    respond_to do |format|
      if @patient.update(patient_params)
        format.html { redirect_to @patient, notice: "Patient was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @patient }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @patient.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /patients/1 or /patients/1.json
  def destroy
    respond_to do |format|
      if @patient.destroy
        format.html { redirect_to patients_path, notice: "Patient was successfully destroyed.", status: :see_other }
        format.json { head :no_content }
      else
        format.html { redirect_to @patient, alert: @patient.errors.full_messages.to_sentence, status: :see_other }
        format.json { render json: @patient.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_patient
      @patient = Patient.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def patient_params
      params.expect(patient: [ :hospital_id, :name, :date_of_birth ])
    end

    def filter_params
      params.permit(:keyword).to_h.symbolize_keys
    end
end
