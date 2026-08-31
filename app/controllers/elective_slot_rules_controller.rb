class ElectiveSlotRulesController < ApplicationController
  before_action :set_elective_slot_rule, only: %i[ show edit update destroy ]

  def index
    rules = ElectiveSlotRule.by_day_of_week
    @elective_slot_rules = (0..6).map { |day_of_week| rules[day_of_week] }
  end

  def show
  end

  def new
    @elective_slot_rule = ElectiveSlotRule.new(day_of_week: params[:day_of_week])
  end

  def edit
  end

  def create
    @elective_slot_rule = ElectiveSlotRule.new(elective_slot_rule_params)

    if @elective_slot_rule.save
      redirect_to @elective_slot_rule, notice: "Elective slot rule was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @elective_slot_rule.update(elective_slot_rule_params)
      redirect_to @elective_slot_rule, notice: "Elective slot rule was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @elective_slot_rule.destroy
      redirect_to elective_slot_rules_path, notice: "Elective slot rule was successfully destroyed.", status: :see_other
    else
      redirect_to @elective_slot_rule, alert: @elective_slot_rule.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

    def set_elective_slot_rule
      @elective_slot_rule = ElectiveSlotRule.find(params.expect(:id))
    end

    def elective_slot_rule_params
      params.expect(elective_slot_rule: [ :day_of_week, :slot_count, :slot_duration_minutes ])
    end
end
