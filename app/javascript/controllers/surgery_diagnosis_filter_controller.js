import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["patientSelect", "diagnosisOption", "emptyState"]

    connect() {
        this.filter()
    }

    filter() {
        const selectedPatientId = this.patientSelectTarget.value
        let visibleCount = 0

        this.diagnosisOptionTargets.forEach((option) => {
            const matchesPatient = selectedPatientId === "" || option.dataset.patientId === selectedPatientId

            option.classList.toggle("hidden", !matchesPatient)

            const checkbox = option.querySelector('input[type="checkbox"]')

            if (!matchesPatient && checkbox) {
                checkbox.checked = false
            }

            if (matchesPatient) {
                visibleCount += 1
            }
        })

        if (this.hasEmptyStateTarget) {
            const showEmptyState = selectedPatientId !== "" && visibleCount === 0
            this.emptyStateTarget.classList.toggle("hidden", !showEmptyState)
        }
    }
}