class PatientsController < ApplicationController
  # Header set by the patient picker's turbo-frame so new/create can tell a
  # picker-modal request apart from `new_patient_path` used as a plain link
  # elsewhere (e.g. the "no patients" warning on the surgery/hospitalization
  # forms), where `turbo_frame_request?` alone would be too broad.
  PICKER_FRAME = "patient_picker_frame".freeze

  before_action :set_patient, only: %i[ show edit update destroy ]
  helper_method :picker_frame_request?

  # GET /patients or /patients.json
  def index
    @pagination = Pagination.new(Patient.filtered(**filter_params).ordered, page: params[:page])
    @patients = @pagination.records
  end

  # GET /patients/picker
  def picker
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

    if picker_frame_request?
      if @patient.save
        render :create, formats: :turbo_stream
      else
        render :new, formats: :turbo_stream, status: :unprocessable_entity
      end
      return
    end

    respond_to do |format|
      if @patient.save
        format.html { redirect_to @patient, notice: t(".success_notice") }
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
        format.html { redirect_to @patient, notice: t(".success_notice"), status: :see_other }
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
        format.html { redirect_to patients_path, notice: t(".success_notice"), status: :see_other }
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
      params.expect(patient: [ :hospital_id, :name, :name_kana, :date_of_birth, :sex, :telephone, :clinical_info ])
    end

    def filter_params
      params.permit(:keyword).to_h.symbolize_keys
    end

    def picker_frame_request?
      request.headers["Turbo-Frame"] == PICKER_FRAME
    end
end
