# The weekly admissions-per-day warning thresholds (入院数の目安): one screen
# for the seven weekdays. Everyone signed in may view; only administrators
# edit. A blank weekday has no row and uses the default. Saving is all or
# nothing (see AdmissionThresholdRule.replace_week). A warning threshold only,
# it never blocks saving a hospitalization.
class AdmissionThresholdRulesController < ApplicationController
  before_action :require_admin, except: :show

  def show
    @rules = AdmissionThresholdRule.thresholds_by_day
  end

  def edit
    @entries = AdmissionThresholdRule.thresholds_by_day
    @errors = {}
  end

  def update
    @entries = entries_from_params
    @errors = AdmissionThresholdRule.replace_week(@entries)

    if @errors.empty?
      redirect_to admission_threshold_rules_path, notice: t(".success_notice"), status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

    def entries_from_params
      permitted = params.fetch(:admission_threshold_rules, {}).permit(*(0..6).map(&:to_s))
      (0..6).index_with { |day| permitted[day.to_s] }
    end
end
