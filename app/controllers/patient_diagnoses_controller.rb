class PatientDiagnosesController < ApplicationController
  before_action :set_patient
  before_action :set_patient_diagnosis, only: %i[ show edit update destroy ]
  before_action :set_diagnoses, only: %i[ new edit create update ]

  def index
    @patient_diagnoses = @patient.patient_diagnoses.includes(:diagnosis).recent_first
  end

  def show
  end

  def new
    @patient_diagnosis = @patient.patient_diagnoses.new
  end

  def edit
  end

  def create
    @patient_diagnosis = @patient.patient_diagnoses.new(patient_diagnosis_params)

    respond_to do |format|
      if @patient_diagnosis.save
        format.html { redirect_to patient_path(@patient), notice: "Diagnosis entry was successfully created." }
        format.json { render :show, status: :created, location: [ @patient, @patient_diagnosis ] }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @patient_diagnosis.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @patient_diagnosis.update(patient_diagnosis_params)
        format.html { redirect_to patient_patient_diagnosis_path(@patient, @patient_diagnosis), notice: "Diagnosis entry was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: [ @patient, @patient_diagnosis ] }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @patient_diagnosis.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @patient_diagnosis.destroy!

    respond_to do |format|
      format.html { redirect_to patient_path(@patient), notice: "Diagnosis entry was successfully deleted.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private

    def set_patient
      @patient = Patient.find(params.expect(:patient_id))
    end

    def set_patient_diagnosis
      @patient_diagnosis = @patient.patient_diagnoses.find(params.expect(:id))
    end

    def set_diagnoses
      @diagnoses = Diagnosis.order(:name)
    end

    def patient_diagnosis_params
      params.expect(patient_diagnosis: [ :diagnosis_id, :diagnosed_on ])
    end
end
