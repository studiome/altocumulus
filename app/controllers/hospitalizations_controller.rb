class HospitalizationsController < ApplicationController
  before_action :set_hospitalization, only: %i[ show edit update destroy ]
  before_action :set_form_collections, only: %i[ new edit create update ]

  def index
    @diagnoses = Diagnosis.alphabetical
    scope = Hospitalization.includes(:patient, hospitalization_diagnoses: :diagnosis)
                            .filtered(**filter_params)
                            .order(admission_date: :desc, created_at: :desc)
    @pagination = Pagination.new(scope, page: params[:page])
    @hospitalizations = @pagination.records
  end

  def show
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
    @hospitalization.destroy!

    respond_to do |format|
      format.html { redirect_to hospitalizations_path, notice: "Hospitalization was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
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
        :patient_id, :admission_date, :planned_days, :reason, :room_preference,
        :discharge_date, :outcome, :discharge_destination,
        { hospitalization_diagnoses_attributes: [ [ :id, :diagnosis_id, :_destroy ] ] }
      ])
    end

    def filter_params
      params.permit(:keyword, :diagnosis_id, :status, :admitted_from, :admitted_to).to_h.symbolize_keys
    end
end
