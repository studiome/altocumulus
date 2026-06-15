import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    connect() {
        const dialog = this.element.closest("dialog")

        if (dialog?.open) {
            dialog.close()
        }

        const id = this.element.dataset.procedureId
        const name = this.element.dataset.procedureName

        if (id && name) {
            const event = new CustomEvent("procedure:created", {
                bubbles: true,
                detail: { id, name }
            })
            this.element.dispatchEvent(event)
        }
    }
}