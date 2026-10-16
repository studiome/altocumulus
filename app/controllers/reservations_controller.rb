# The unified reservation (入約) form: see Reservation. Any signed-in user may
# use it, like the hospitalization and surgery screens it replaces on the
# calendar's booking flow.
#
# The collection actions render the small turbo-frames the form refreshes as
# its inputs change (patient confirmation card, admission count of a date,
# slot summary of a date, team members for a date, month mini-calendar).
class ReservationsController < ApplicationController
  include CalendarReturn

  ANNOUNCEMENT_LIMIT = 5

  before_action :set_reservation_for_edit, only: %i[ edit update ]
  before_action :require_teams_feature, only: :team_members

  def new
    @reservation = Reservation.build_new(
      user: current_user, surgery_date: params[:surgery_date], scheduled_admission_date: params[:scheduled_admission_date],
      scheduled_procedure_date: params[:scheduled_procedure_date],
      purpose: params[:purpose], patient_id: params[:patient_id]
    )
    prepare_form
  end

  def edit
    prepare_form
  end

  def create
    @reservation = Reservation.new.assign(reservation_params)

    if @reservation.save
      redirect_after_save(t(".success_notice"))
    else
      prepare_form
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @reservation.update(reservation_params)
      redirect_after_save(t(".success_notice"), status: :see_other)
    else
      prepare_form
      render :edit, status: :unprocessable_entity
    end
  end

  # GET /reservations/patient_card?patient_id=1
  def patient_card
    @patient = Patient.find_by(id: params[:patient_id].presence)
    @recent_hospitalizations = recent_hospitalizations_of(@patient)
  end

  # GET /reservations/admission_calendar?month=2026-11&selected=2026-11-10
  def admission_calendar
    @admission_calendar = AdmissionCalendar.new(month: AdmissionCalendar.parse_month(params[:month]))
    @selected_date = Reservation.parse_date(params[:selected])
  end

  # GET /reservations/admission_count?date=2026-11-10
  def admission_count
    @date = Reservation.parse_date(params[:date])
    @count = AdmissionCalendar.count_on(@date) if @date
    @threshold = Rails.application.config.x.admission_warning_threshold
  end

  # GET /reservations/slot_summary?date=2026-11-10
  def slot_summary
    @date = Reservation.parse_date(params[:date])
    @usage = ElectiveSlotUsage.for_dates([ @date ])[@date] if @date
  end

  # GET /reservations/team_members?team_id=1&date=2026-11-10
  def team_members
    @date = Reservation.parse_date(params[:date])
    @team = Team.find_by(id: params[:team_id].presence)
    @term = @team&.term_for(@date)
  end

  private

    def set_reservation_for_edit
      @reservation = Reservation.for_hospitalization(Hospitalization.active.find(params.expect(:id)))
    end

    def prepare_form
      hospitalization = @reservation.hospitalization
      @admission_calendar = AdmissionCalendar.new(month: (hospitalization.effective_admission_date || Date.current))
      @announcements = Announcement.published.recent_first.limit(ANNOUNCEMENT_LIMIT).to_a
      @patient = hospitalization.patient
      @recent_hospitalizations = recent_hospitalizations_of(@patient)
    end

    # The patient's last two hospitalizations, to confirm it is the right chart.
    def recent_hospitalizations_of(patient)
      return [] unless patient

      patient.hospitalizations.active
             .includes(surgeries: { surgery_procedure_selections: :surgery_procedure })
             .order(Arel.sql("COALESCE(admission_date, scheduled_admission_date) DESC"), id: :desc)
             .limit(2).to_a
    end

    # A dated surgery is best seen in its place on the operations calendar;
    # anything else (examination, undated surgery) goes to the hospitalization.
    def redirect_after_save(notice, **options)
      surgery = @reservation.surgery
      if @reservation.surgery_applicable? && surgery&.surgery_date
        flash[:notice_link] = { "path" => surgery_path(surgery), "label" => t("common.view_details") }
        redirect_to calendar_path_for_saved(surgery.surgery_date), notice: notice, **options
      else
        redirect_to hospitalization_path(@reservation.hospitalization), notice: notice, **options
      end
    end

    def require_teams_feature
      head :not_found unless SiteConfig.current.teams_enabled?
    end

    # The team is only a field while the site uses teams (features.teams).
    def team_params
      SiteConfig.current.teams_enabled? ? [ :team_id ] : []
    end

    def reservation_params
      params.expect(reservation: [
        { hospitalization: [
          *team_params,
          :patient_id, :purpose, :reason, :scheduled_admission_date, :planned_days, :emergency_admission,
          :transfer_status, :source_department_id, :referred_from, :reservation_doctor_id, :attending_doctor,
          :adl, :room_preference, :scheduled_procedure_date, :procedure_name, :clinical_comment
        ] },
        { surgery: [
          :surgery_date, :surgery_date_status, :scheduling_type, :slot_category, :department_id, :backup_intervention,
          :surgery_location_id, :performing_department_id, :surgical_device_id, :duration_hours, :anesthesia_method,
          :operator_name, :assistant_name, :start_time, :slot_number, :operation_order
        ] },
        { diagnoses: [ [ :id, :diagnosis_id, :laterality, :_destroy ] ] },
        { procedures: [ [ :id, :surgery_procedure_id, :laterality, :_destroy ] ] }
      ])
    end
end
