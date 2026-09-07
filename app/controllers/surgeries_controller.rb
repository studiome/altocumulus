class SurgeriesController < ApplicationController
  before_action :set_surgery, only: %i[ edit update destroy ]
  before_action :set_form_collections, only: %i[ new edit create update ]

  def index
    @surgery_procedures = SurgeryProcedure.alphabetical
    @anesthesia_methods = Surgery.anesthesia_methods
    scope = Surgery.includes(:patient, :hospitalization, { patient_diagnoses: :diagnosis }, { surgery_procedure_selections: :surgery_procedure })
                    .filtered(**filter_params)
                    .ordered_by_surgery_date
    @pagination = Pagination.new(scope, page: params[:page])
    @surgeries = @pagination.records
    @slot_rules = ElectiveSlotRule.by_day_of_week
  end

  def show
    @surgery = Surgery.includes(:patient, { patient_diagnoses: :diagnosis }, { surgery_procedure_selections: :surgery_procedure })
                       .find(params.expect(:id))
    @slot_rules = ElectiveSlotRule.by_day_of_week
    @holiday = Holiday.find_by(date: @surgery.surgery_date)
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
      if save_surgery { @surgery.save }
        format.html { redirect_to @surgery, notice: t(".success_notice") }
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
      if save_surgery { @surgery.update(surgery_params) }
        format.html { redirect_to @surgery, notice: t(".success_notice"), status: :see_other }
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
        format.html { redirect_to surgeries_path, notice: t(".success_notice"), status: :see_other }
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
      @hospitalizations = Hospitalization.active.includes(:patient).order(admission_date: :desc)
      @elective_slot_rules = ElectiveSlotRule.ordered
    end

    # Nested selections are saved row by row, so exchanging procedures between
    # two existing rows hits the unique index mid-save even though the final
    # state is valid. Surface that as a validation error instead of a 500.
    def save_surgery
      yield
    rescue ActiveRecord::RecordNotUnique => e
      if e.message.include?("surgery_procedure_selections")
        @surgery.errors.add(:surgery_procedure_selections, :cannot_swap_procedures_between_rows)
        false
      else
        raise e
      end
    end

    def build_surgery_procedure_selections
      @surgery.surgery_procedure_selections.build if @surgery.surgery_procedure_selections.empty?
    end

    def surgery_params
      params.expect(surgery: [
        :surgery_date, :surgery_date_status, :duration_hours, :anesthesia_method, :patient_id, :hospitalization_id,
        :scheduling_type, :start_time, :slot_number,
        :operator_name, :assistant_name, :operation_order,
        { patient_diagnosis_ids: [] },
        { surgery_procedure_selections_attributes: [ [ :id, :surgery_procedure_id, :laterality, :_destroy ] ] }
      ])
    end

    def filter_params
      params.permit(:keyword, :surgery_procedure_id, :anesthesia_method, :performed_from, :performed_to, :scheduling_type, :undated).to_h.symbolize_keys
    end
end
