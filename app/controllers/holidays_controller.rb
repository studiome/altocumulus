class HolidaysController < ApplicationController
  before_action :set_holiday, only: %i[ show edit update destroy ]

  def index
    @available_years = Holiday.available_years
    scope = Holiday.filtered(**filter_params).ordered
    @pagination = Pagination.new(scope, page: params[:page])
    @holidays = @pagination.records
  end

  def show
  end

  def new
    @holiday = Holiday.new
  end

  def edit
  end

  def create
    @holiday = Holiday.new(holiday_params)

    if @holiday.save
      redirect_to @holiday, notice: "Holiday was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @holiday.update(holiday_params)
      redirect_to @holiday, notice: "Holiday was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @holiday.destroy
      redirect_to holidays_path, notice: "Holiday was successfully destroyed.", status: :see_other
    else
      redirect_to @holiday, alert: @holiday.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

    def set_holiday
      @holiday = Holiday.find(params.expect(:id))
    end

    def holiday_params
      params.expect(holiday: [ :date, :name ])
    end

    def filter_params
      params.permit(:year).to_h.symbolize_keys
    end
end
