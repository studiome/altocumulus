import { Controller } from "@hotwired/stimulus"

// Shared open/close behaviour for the <dialog> wrappers around a picker
// turbo-frame (diagnoses, surgery procedures, a patient's diagnoses).
export default class extends Controller {
    open() {
        if (!this.element.open) {
            this.element.showModal()
        }
    }

    close() {
        if (this.element.open) {
            this.element.close()
        }
    }
}
