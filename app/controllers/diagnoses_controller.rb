class DiagnosesController < ApplicationController
  before_action :set_diagnosis, only: %i[ show edit update destroy ]

  def index
    @diagnoses = Diagnosis.order(:name)
  end

  def show
  end

  def new
    @diagnosis = Diagnosis.new
  end

  def edit
  end

  def create
    @diagnosis = Diagnosis.new(diagnosis_params)

    if @diagnosis.save
      redirect_to @diagnosis, notice: "Diagnosis was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @diagnosis.update(diagnosis_params)
      redirect_to @diagnosis, notice: "Diagnosis was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @diagnosis.destroy!
    redirect_to diagnoses_path, notice: "Diagnosis was successfully destroyed.", status: :see_other
  end

  private

    def set_diagnosis
      @diagnosis = Diagnosis.find(params.expect(:id))
    end

    def diagnosis_params
      params.expect(diagnosis: [ :name ])
    end
end
