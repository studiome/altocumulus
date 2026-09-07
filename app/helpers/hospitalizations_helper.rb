module HospitalizationsHelper
  # Single source of truth for how a hospitalization's length of stay reads
  # on screen, shared by the index table and the show page so the two never
  # drift apart. The underlying numbers (#length_of_stay, #days_since_admission)
  # stay on the model; only the display string lives here.
  def length_of_stay_display(hospitalization)
    if hospitalization.length_of_stay.present?
      "#{hospitalization.length_of_stay} days"
    elsif hospitalization.days_since_admission.present?
      "Day #{hospitalization.days_since_admission} (ongoing)"
    else
      "-"
    end
  end
end
