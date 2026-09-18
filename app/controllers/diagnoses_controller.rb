class DiagnosesController < ApplicationController
  # Frame of the diagnosis picker modal used by the hospitalization form. The
  # older `diagnosis_modal_frame` (patient diagnoses form) is still around, so
  # new/create tell the two apart by the frame name rather than by
  # `turbo_frame_request?` alone.
  PICKER_FRAME = "diagnosis_picker_frame".freeze

  before_action :set_diagnosis, only: %i[ show edit update destroy ]
  helper_method :picker_frame_request?

  def index
    @diagnoses = Diagnosis.alphabetical
  end

  # GET /diagnoses/picker
  def picker
    @pagination = Pagination.new(Diagnosis.filtered(**filter_params).alphabetical, page: params[:page])
    @diagnoses = @pagination.records
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

    if picker_frame_request?
      if @diagnosis.save
        render :picker_create, formats: :turbo_stream
      else
        render :picker_new, formats: :turbo_stream, status: :unprocessable_entity
      end
      return
    end

    if @diagnosis.save
      if turbo_frame_request?
        @diagnoses = Diagnosis.alphabetical
        render :create, formats: :turbo_stream
      else
        redirect_to @diagnosis, notice: t(".success_notice")
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
      redirect_to @diagnosis, notice: t(".success_notice"), status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @diagnosis.destroy
      redirect_to diagnoses_path, notice: t(".success_notice"), status: :see_other
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

    def filter_params
      params.permit(:keyword).to_h.symbolize_keys
    end

    def picker_frame_request?
      request.headers["Turbo-Frame"] == PICKER_FRAME
    end
end
