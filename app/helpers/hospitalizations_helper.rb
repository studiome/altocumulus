module HospitalizationsHelper
  # Single source of truth for how a hospitalization's length of stay reads
  # on screen, shared by the index table and the show page so the two never
  # drift apart. The underlying numbers (#length_of_stay, #days_since_admission)
  # stay on the model; only the display string lives here.
  def length_of_stay_display(hospitalization)
    if hospitalization.length_of_stay.present?
      I18n.t("helpers.hospitalizations.length_of_stay.days", count: hospitalization.length_of_stay)
    elsif hospitalization.days_since_admission.present?
      I18n.t("helpers.hospitalizations.length_of_stay.ongoing", count: hospitalization.days_since_admission)
    else
      I18n.t("helpers.hospitalizations.length_of_stay.unknown")
    end
  end
end
