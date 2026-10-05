class SurgeriesController < ApplicationController
  include CalendarReturn

  DEFAULT_LOOKBACK_DAYS = 7

  before_action :set_surgery, only: %i[ edit update destroy ]

  def index
    @surgery_procedures = SurgeryProcedure.alphabetical
    @anesthesia_methods = Surgery.anesthesia_methods
    @default_range = default_range?
    scope = Surgery.includes(:patient, { patient_diagnoses: :diagnosis }, { surgery_procedure_selections: :surgery_procedure })
                    .filtered(**index_filters)
                    .ascending_by_surgery_date
    @pagination = Pagination.new(scope, page: params[:page])
    @surgeries = @pagination.records
    @holidays = Holiday.by_date(@surgeries.filter_map(&:surgery_date))
    @slot_rules = ElectiveSlotRule.by_day_of_week
  end

  def show
    @surgery = Surgery.includes(:patient, { patient_diagnoses: :diagnosis }, { surgery_procedure_selections: :surgery_procedure })
                       .find(params.expect(:id))
    @slot_rules = ElectiveSlotRule.by_day_of_week
    @holidays = Holiday.by_date([ @surgery.surgery_date ].compact)
    @holiday = @holidays[@surgery.surgery_date]
  end

  def new
    @surgery = Surgery.new(patient_id: params[:patient_id], surgery_date: parse_date(params[:surgery_date]))
    set_form_collections
    build_surgery_procedure_selections
  end

  def edit
    set_form_collections
    build_surgery_procedure_selections
  end

  def create
    @surgery = Surgery.new(surgery_params)

    respond_to do |format|
      if save_surgery { @surgery.save }
        format.html { redirect_after_save(t(".success_notice")) }
        format.json { render :show, status: :created, location: @surgery }
      else
        set_form_collections
        build_surgery_procedure_selections if @surgery.surgery_procedure_selections.empty?
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @surgery.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if save_surgery { @surgery.update(surgery_params) }
        format.html { redirect_after_save(t(".success_notice"), status: :see_other) }
        format.json { render :show, status: :ok, location: @surgery }
      else
        set_form_collections
        build_surgery_procedure_selections if @surgery.surgery_procedure_selections.empty?
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @surgery.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /surgeries/patient_fields?patient_id=123
  # Called from the surgery form's turbo-frame when the picked patient
  # changes, so only that patient's diagnoses are ever sent to the browser
  # instead of every patient's.
  def patient_fields
    @patient_id = params[:patient_id].presence
    @patient_diagnoses = patient_diagnoses_for(@patient_id)
    @selected_patient_diagnosis_ids = []
  end

  # GET /surgeries/diagnosis_picker?patient_id=123
  # Feeds the surgery form's related-diagnoses picker modal with just the
  # picked patient's diagnoses, for the same reason as #patient_fields.
  def diagnosis_picker
    @patient_id = params[:patient_id].presence
    @patient_diagnoses = patient_diagnoses_for(@patient_id)
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

    # A dated surgery is best seen in its place on the operations calendar;
    # the notice links on to its detail page. An undated one has no day to
    # show, so it goes straight to its detail page.
    def redirect_after_save(notice, **options)
      return redirect_to(@surgery, notice: notice, **options) if @surgery.surgery_date.blank?

      flash[:notice_link] = { "path" => surgery_path(@surgery), "label" => t("common.view_details") }
      redirect_to calendar_path_for_saved(@surgery.surgery_date), notice: notice, **options
    end

    def set_surgery
      @surgery = Surgery.find(params.expect(:id))
    end

    def set_form_collections
      @patients = Patient.order(:id)
      @surgery_procedures = SurgeryProcedure.alphabetical
      @elective_slot_rules = ElectiveSlotRule.ordered
      @patient_diagnoses = patient_diagnoses_for(@surgery&.patient_id)
    end

    # Patient not yet chosen: empty, rather than the old approach of loading
    # every patient's diagnoses and hiding the wrong ones with CSS.
    def patient_diagnoses_for(patient_id)
      return PatientDiagnosis.none if patient_id.blank?

      PatientDiagnosis.where(patient_id: patient_id).includes(:diagnosis).recent_first
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

    # Prefill params are untrusted: anything that is not a parsable date
    # string (typo, crafted array) simply leaves the field blank.
    def parse_date(value)
      Date.iso8601(value) if value.is_a?(String)
    rescue Date::Error
      nil
    end

    def build_surgery_procedure_selections
      @surgery.surgery_procedure_selections.build if @surgery.surgery_procedure_selections.empty?
    end

    def surgery_params
      params.expect(surgery: [
        :surgery_date, :surgery_date_status, :duration_hours, :anesthesia_method, :patient_id,
        :scheduling_type, :slot_category, :target_department, :location, :start_time, :slot_number,
        :operator_name, :assistant_name, :operation_order,
        { patient_diagnosis_ids: [] },
        { surgery_procedure_selections_attributes: [ [ :id, :surgery_procedure_id, :laterality, :_destroy ] ] }
      ])
    end

    # Opened with no filter at all (and not via the "all dates" link): start
    # a week back instead of listing every surgery ever. `page` is not a
    # filter, so paging through the default view stays in it.
    def default_range?
      filter_params.empty? && params[:all].blank?
    end

    def index_filters
      return filter_params unless @default_range

      @performed_from = (Date.current - DEFAULT_LOOKBACK_DAYS).iso8601
      { performed_from: @performed_from, include_undated: true }
    end

    def filter_params
      params.permit(:keyword, :surgery_procedure_id, :anesthesia_method, :performed_from, :performed_to, :scheduling_type, :slot_category, :undated).to_h.symbolize_keys
    end
end
