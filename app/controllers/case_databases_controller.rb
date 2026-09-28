class CaseDatabasesController < ApplicationController
  before_action :set_case_database, only: %i[ show edit update destroy ]
  before_action :require_data_manager, only: %i[ new create edit update destroy ]

  def index
    @case_databases = CaseDatabase.order(:name)
  end

  def show
    @entries = @case_database.entries.includes(:patient).joins(:patient).order("patients.hospital_id")

    respond_to do |format|
      format.html
      format.csv do
        send_data @case_database.to_csv,
                  type: "text/csv; charset=utf-8",
                  filename: "case_database_#{@case_database.id}_#{Date.current.strftime('%Y%m%d')}.csv"
      end
    end
  end

  def new
    @case_database = CaseDatabase.new
  end

  def edit
  end

  def create
    @case_database = CaseDatabase.new(case_database_params)

    if @case_database.save
      redirect_to @case_database, notice: t(".success_notice")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @case_database.update(case_database_params)
      redirect_to @case_database, notice: t(".success_notice"), status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @case_database.destroy
    redirect_to case_databases_path, notice: t(".success_notice"), status: :see_other
  end

  private

    def set_case_database
      @case_database = CaseDatabase.find(params.expect(:id))
    end

    def case_database_params
      params.expect(case_database: [ :name, :description ])
    end
end
