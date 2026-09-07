class HospitalizationsController < ApplicationController
  before_action :set_hospitalization, only: %i[ show edit update destroy confirm restore copy ]
  before_action :set_form_collections, only: %i[ new edit create update ]
  before_action :require_admin, only: %i[ confirm restore copy deleted ]

  def index
    @diagnoses = Diagnosis.alphabetical
    scope = Hospitalization.includes(:patient, hospitalization_diagnoses: :diagnosis)
                            .filtered(**filter_params)
                            .order(Arel.sql("COALESCE(hospitalizations.admission_date, hospitalizations.scheduled_admission_date) DESC"), created_at: :desc)
    @pagination = Pagination.new(scope, page: params[:page])
    @hospitalizations = @pagination.records
  end

  def show
    @surgeries = @hospitalization.surgeries
                                 .includes(surgery_procedure_selections: :surgery_procedure)
                                 .order(surgery_date: :asc)
  end

  def new
    @hospitalization = Hospitalization.new(patient_id: params[:patient_id])
    build_hospitalization_diagnoses
  end

  def edit
    build_hospitalization_diagnoses
  end

  def create
    @hospitalization = Hospitalization.new(hospitalization_params)

    respond_to do |format|
      if save_hospitalization { @hospitalization.save }
        format.html { redirect_to @hospitalization, notice: "Hospitalization was successfully created." }
        format.json { render :show, status: :created, location: @hospitalization }
      else
        build_hospitalization_diagnoses if @hospitalization.hospitalization_diagnoses.empty?
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @hospitalization.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if save_hospitalization { @hospitalization.update(hospitalization_params) }
        format.html { redirect_to @hospitalization, notice: "Hospitalization was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @hospitalization }
      else
        build_hospitalization_diagnoses if @hospitalization.hospitalization_diagnoses.empty?
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @hospitalization.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @hospitalization.discard!

    respond_to do |format|
      format.html { redirect_to hospitalizations_path, notice: "Hospitalization was successfully deleted.", status: :see_other }
      format.json { head :no_content }
    end
  end

  def confirm
    @hospitalization.update!(admin_status: "confirmed")
    redirect_to @hospitalization, notice: "Hospitalization was confirmed."
  end

  def restore
    @hospitalization.restore!
    redirect_to @hospitalization, notice: "Hospitalization was restored."
  end

  def deleted
    @hospitalizations = Hospitalization.discarded.includes(:patient).order(updated_at: :desc)
  end

  def copy
    @copy = @hospitalization.rebook(scheduled_admission_date: params[:scheduled_admission_date])

    if @copy.persisted?
      redirect_to edit_hospitalization_path(@copy), notice: "Hospitalization was copied. Fill in the remaining details."
    else
      redirect_to @hospitalization, alert: "Could not copy: #{@copy.errors.full_messages.to_sentence}"
    end
  end

  private

    def set_hospitalization
      @hospitalization = Hospitalization.find(params.expect(:id))
    end

    def set_form_collections
      @patients = Patient.order(:id)
      @diagnoses = Diagnosis.alphabetical
    end

    # Nested diagnoses are saved row by row, so exchanging diagnoses between
    # two existing rows hits the unique index mid-save even though the final
    # state is valid. Surface that as a validation error instead of a 500.
    def save_hospitalization
      yield
    rescue ActiveRecord::RecordNotUnique => e
      if e.message.include?("hospitalization_diagnoses")
        @hospitalization.errors.add(:hospitalization_diagnoses, "cannot swap diagnoses between existing rows in one save; change one row to a different diagnosis first")
        false
      else
        raise e
      end
    end

    def build_hospitalization_diagnoses
      @hospitalization.hospitalization_diagnoses.build if @hospitalization.hospitalization_diagnoses.empty?
    end

    def hospitalization_params
      params.expect(hospitalization: [
        :patient_id, :admission_date, :scheduled_admission_date, :reservation_status, :purpose,
        :planned_days, :reason, :room_preference, :ward, :referred_from, :adl,
        :reservation_doctor, :attending_doctor, :submitted_on, :clinical_comment,
        :discharge_date, :outcome, :discharge_destination,
        { hospitalization_diagnoses_attributes: [ [ :id, :diagnosis_id, :_destroy ] ] }
      ])
    end

    def filter_params
      params.permit(:keyword, :diagnosis_id, :status, :admitted_from, :admitted_to).to_h.symbolize_keys
    end
end
