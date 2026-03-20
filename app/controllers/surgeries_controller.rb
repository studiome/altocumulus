class SurgeriesController < ApplicationController
  before_action :set_surgery, only: %i[ show edit update destroy ]
  before_action :set_patients, only: %i[ new edit create update ]

  # GET /surgeries or /surgeries.json
  def index
    @surgeries = Surgery.includes(:patient).order(surgery_date: :desc, created_at: :desc)
  end

  # GET /surgeries/1 or /surgeries/1.json
  def show
  end

  # GET /surgeries/new
  def new
    @surgery = Surgery.new(patient_id: params[:patient_id])
  end

  # GET /surgeries/1/edit
  def edit
  end

  # POST /surgeries or /surgeries.json
  def create
    @surgery = Surgery.new(surgery_params)

    respond_to do |format|
      if @surgery.save
        format.html { redirect_to @surgery, notice: "Surgery was successfully created." }
        format.json { render :show, status: :created, location: @surgery }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @surgery.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /surgeries/1 or /surgeries/1.json
  def update
    respond_to do |format|
      if @surgery.update(surgery_params)
        format.html { redirect_to @surgery, notice: "Surgery was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @surgery }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @surgery.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /surgeries/1 or /surgeries/1.json
  def destroy
    @surgery.destroy!

    respond_to do |format|
      format.html { redirect_to surgeries_path, notice: "Surgery was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    def set_surgery
      @surgery = Surgery.find(params.expect(:id))
    end

    def set_patients
      @patients = Patient.order(:id)
    end

    def surgery_params
      params.expect(surgery: [ :surgery_date, :procedure, :duration_hours, :anesthesia_method, :patient_id ])
    end
end
