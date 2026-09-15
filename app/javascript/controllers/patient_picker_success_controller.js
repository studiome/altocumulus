import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    connect() {
        const dialog = this.element.closest("dialog")

        if (dialog?.open) {
            dialog.close()
        }

        const id = this.element.dataset.patientId
        const label = this.element.dataset.patientLabel

        if (id && label) {
            const event = new CustomEvent("patient:selected", {
                bubbles: true,
                detail: { id, label }
            })
            this.element.dispatchEvent(event)
        }
    }
}
