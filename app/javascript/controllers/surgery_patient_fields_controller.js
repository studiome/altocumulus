import { Controller } from "@hotwired/stimulus"

// The patient picker used to be paired with every patient's diagnoses
// rendered into the page and hidden with CSS for the unselected ones. That
// leaked other patients' names/diagnoses into the HTML source. Instead, when
// the patient changes, re-fetch just that patient's fields from the server
// and swap them into the turbo-frame.
export default class extends Controller {
    static targets = ["frame"]
    static values = { url: String }

    reload(event) {
        const patientId = event.target.value
        const url = new URL(this.urlValue, window.location.origin)

        if (patientId) {
            url.searchParams.set("patient_id", patientId)
        }

        this.frameTarget.src = url.toString()
    }
}
