# A single cross-cutting search entry point over patients, hospitalizations,
# and surgeries. Deliberately does not reimplement any matching logic: each
# section just calls that model's own `.filtered(keyword:)`, so a change to
# what counts as a match for, say, Hospitalization stays in one place
# (Hospitalization.filtered) and is automatically picked up here too. That
# also means soft-deleted hospitalizations are excluded the same way they
# already are everywhere else (Hospitalization.filtered scopes to `.active`
# unconditionally), with no extra role-based filtering needed here.
class SearchesController < ApplicationController
  RESULT_LIMIT = 20

  def index
    @keyword = params[:keyword].to_s.strip

    if @keyword.present?
      @patients = Patient.filtered(keyword: @keyword).ordered.limit(RESULT_LIMIT)
      @hospitalizations = Hospitalization.filtered(keyword: @keyword)
                                          .includes(:patient)
                                          .order(Arel.sql("COALESCE(hospitalizations.admission_date, hospitalizations.scheduled_admission_date) DESC"))
                                          .limit(RESULT_LIMIT)
      @surgeries = Surgery.filtered(keyword: @keyword)
                           .includes(:patient)
                           .ordered_by_surgery_date
                           .limit(RESULT_LIMIT)
    else
      @patients = Patient.none
      @hospitalizations = Hospitalization.none
      @surgeries = Surgery.none
    end
  end
end
