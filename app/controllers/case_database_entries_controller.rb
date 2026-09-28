class CaseDatabaseEntriesController < ApplicationController
  before_action :set_case_database
  before_action :set_entry, only: %i[ edit update destroy ]
  before_action :require_data_manager, only: %i[ destroy ]

  # GET /case_databases/1/entries/new
  # A patient search page (not a "new entry" form): field values are entered
  # afterward via #edit/#update.
  def new
    already_added_ids = @case_database.entries.select(:patient_id)
    scope = Patient.filtered(**filter_params).where.not(id: already_added_ids).ordered
    @pagination = Pagination.new(scope, page: params[:page])
    @patients = @pagination.records
  end

  def create
    patient = Patient.find(params.expect(:patient_id))
    @entry = @case_database.entries.new(patient: patient)

    if @entry.save
      redirect_to @case_database, notice: t(".success_notice")
    else
      redirect_to @case_database, alert: @entry.errors.full_messages.to_sentence
    end
  end

  def edit
  end

  def update
    @entry.assign_field_values(entry_params[:field_values])

    if @entry.save
      redirect_to @case_database, notice: t(".success_notice"), status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @entry.destroy
    redirect_to @case_database, notice: t(".success_notice"), status: :see_other
  end

  private

    def set_case_database
      @case_database = CaseDatabase.find(params.expect(:case_database_id))
    end

    def set_entry
      @entry = @case_database.entries.find(params.expect(:id))
    end

    def filter_params
      params.permit(:keyword).to_h.symbolize_keys
    end

    def entry_params
      params.fetch(:case_database_entry, {}).permit(field_values: @case_database.fields.map { |field| field.id.to_s })
    end
end
