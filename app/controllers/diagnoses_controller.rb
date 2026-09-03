class DiagnosesController < ApplicationController
  before_action :set_diagnosis, only: %i[ show edit update destroy ]

  def index
    @diagnoses = Diagnosis.alphabetical
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
      if turbo_frame_request?
        @diagnoses = Diagnosis.alphabetical
        render :create, formats: :turbo_stream
      else
        redirect_to @diagnosis, notice: "Diagnosis was successfully created."
      end
    else
      if turbo_frame_request?
        render :new, formats: :turbo_stream, status: :unprocessable_entity
      else
        render :new, formats: :html, status: :unprocessable_entity
      end
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
    if @diagnosis.destroy
      redirect_to diagnoses_path, notice: "Diagnosis was successfully destroyed.", status: :see_other
    else
      redirect_to diagnosis_path(@diagnosis), alert: @diagnosis.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

    def set_diagnosis
      @diagnosis = Diagnosis.find(params.expect(:id))
    end

    def diagnosis_params
      params.expect(diagnosis: [ :name ])
    end
end
