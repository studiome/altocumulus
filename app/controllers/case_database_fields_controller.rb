class CaseDatabaseFieldsController < ApplicationController
  before_action :require_data_manager
  before_action :set_case_database
  before_action :set_field, only: %i[ edit update destroy ]

  def new
    @field = @case_database.fields.new
  end

  def create
    @field = @case_database.fields.new(field_params)

    if @field.save
      redirect_to @case_database, notice: t(".success_notice")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @field.update(field_params)
      redirect_to @case_database, notice: t(".success_notice"), status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @field.destroy
    redirect_to @case_database, notice: t(".success_notice"), status: :see_other
  end

  private

    def set_case_database
      @case_database = CaseDatabase.find(params.expect(:case_database_id))
    end

    def set_field
      @field = @case_database.fields.find(params.expect(:id))
    end

    def field_params
      params.expect(case_database_field: [ :label, :field_type, :options, :position ])
    end
end
