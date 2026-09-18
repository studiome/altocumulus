import { Controller } from "@hotwired/stimulus"

// The surgery's related diagnoses used to be a checkbox per diagnosis of the
// picked patient. They are now picked one at a time from a modal, so the rows
// (each one a hidden surgery[patient_diagnosis_ids][] input) are built here
// from a <template> as the user picks them.
export default class extends Controller {
    static targets = ["list", "template", "item", "empty"]

    connect() {
        this.refreshEmptyState()
    }

    add(event) {
        const { id, label } = event.detail
        if (!id) return
        if (this.listTarget.querySelector(`[data-patient-diagnosis-id="${CSS.escape(id)}"]`)) return

        const row = this.templateTarget.content.firstElementChild.cloneNode(true)
        row.dataset.patientDiagnosisId = id
        row.querySelector("[data-picker-input]").value = id
        row.querySelector("[data-picker-label]").textContent = label
        this.listTarget.appendChild(row)
        this.refreshEmptyState()
    }

    remove(event) {
        event.currentTarget.closest("[data-surgery-diagnosis-fields-target='item']")?.remove()
        this.refreshEmptyState()
    }

    refreshEmptyState() {
        if (!this.hasEmptyTarget) return

        this.emptyTarget.hidden = this.itemTargets.length > 0
    }
}
