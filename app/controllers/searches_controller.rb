# A single cross-cutting search entry point over patients, hospitalizations,
# and surgeries. Deliberately does not reimplement any matching logic: each
# tab just calls that model's own `.filtered(keyword:)`, so a change to
# what counts as a match for, say, Hospitalization stays in one place
# (Hospitalization.filtered) and is automatically picked up here too. That
# also means soft-deleted hospitalizations are excluded the same way they
# already are everywhere else (Hospitalization.filtered scopes to `.active`
# unconditionally), with no extra role-based filtering needed here.
#
# Results are split into tabs (`tab`, see TABS): every tab shows its match
# count, but only the selected one loads its rows. Without a valid `tab`, the
# first tab that has any match is opened.
class SearchesController < ApplicationController
  RESULT_LIMIT = 20
  TABS = %w[hospitalizations surgeries patients].freeze

  def index
    @keyword = params[:keyword].to_s.strip
    return if @keyword.blank?

    @counts = TABS.index_with { |tab| scope_for(tab).count }
    @tab = TABS.include?(params[:tab]) ? params[:tab] : (TABS.find { |tab| @counts[tab].positive? } || TABS.first)
    @results = rows_for(@tab)
    @holidays = Holiday.by_date(result_dates) unless @tab == "patients"
  end

  private

    def scope_for(tab)
      case tab
      when "hospitalizations" then Hospitalization.filtered(keyword: @keyword)
      when "surgeries" then Surgery.filtered(keyword: @keyword)
      when "patients" then Patient.filtered(keyword: @keyword)
      end
    end

    def rows_for(tab)
      case tab
      when "hospitalizations"
        scope_for(tab).includes(:patient, hospitalization_diagnoses: :diagnosis)
                      .order(Arel.sql("COALESCE(hospitalizations.admission_date, hospitalizations.scheduled_admission_date) DESC"))
                      .limit(RESULT_LIMIT)
      when "surgeries"
        scope_for(tab).includes(:patient, :department, :surgery_location, { patient_diagnoses: :diagnosis }, { surgery_procedure_selections: :surgery_procedure })
                      .ordered_by_surgery_date
                      .limit(RESULT_LIMIT)
      when "patients"
        scope_for(tab).ordered.limit(RESULT_LIMIT)
      end
    end

    def result_dates
      if @tab == "hospitalizations"
        @results.flat_map { |hospitalization| [ hospitalization.effective_admission_date, hospitalization.discharge_date ] }.compact
      else
        @results.filter_map(&:surgery_date)
      end
    end
end
