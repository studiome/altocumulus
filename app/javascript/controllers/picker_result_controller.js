import { Controller } from "@hotwired/stimulus"

// Turns a click on a picker result row into a window-level event that the
// waiting picker field (or list) picks up, then closes the modal.
export default class extends Controller {
    static values = { event: String }

    select(event) {
        const { pickerId, pickerLabel } = event.currentTarget.dataset

        this.emit(pickerId, pickerLabel)
    }

    // Used by the "record created" frame: the record the user just created in
    // the modal is the one they wanted, so it is picked right away.
    connect() {
        const { pickerId, pickerLabel } = this.element.dataset

        if (this.element.dataset.pickerAutoselect === "true" && pickerId && pickerLabel) {
            this.emit(pickerId, pickerLabel)
        }
    }

    emit(id, label) {
        if (!id || !label) return

        this.element.dispatchEvent(new CustomEvent(this.eventValue, {
            bubbles: true,
            detail: { id, label }
        }))

        this.element.closest("dialog")?.close()
    }
}
