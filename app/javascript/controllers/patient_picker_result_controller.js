import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    select(event) {
        const { patientId, patientLabel } = event.currentTarget.dataset

        const customEvent = new CustomEvent("patient:selected", {
            bubbles: true,
            detail: { id: patientId, label: patientLabel }
        })
        this.element.dispatchEvent(customEvent)

        this.element.closest("dialog")?.close()
    }
}
