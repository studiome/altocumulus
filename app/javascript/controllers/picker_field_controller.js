import { Controller } from "@hotwired/stimulus"

// A read-only display + hidden input pair that is filled from a picker modal,
// the same interaction as the patient picker. The modal is rendered once per
// page while the form can hold many of these fields (one per diagnosis or
// procedure row), so the field that opened the modal records itself here and
// every other field ignores the resulting event.
let activeField = null

export default class extends Controller {
    static targets = ["input", "display"]
    static values = { placeholder: String }

    // Fired on the "choose" link, just before Turbo loads the picker frame.
    activate() {
        activeField = this
    }

    disconnect() {
        if (activeField === this) activeField = null
    }

    receive(event) {
        if (activeField !== this) return

        const { id, label, name } = event.detail
        this.inputTarget.value = id
        this.displayTarget.textContent = label || name
        this.displayTarget.classList.remove("text-base-content/50")
        this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
        activeField = null
    }

    clear() {
        this.inputTarget.value = ""
        this.displayTarget.textContent = this.placeholderValue
        this.displayTarget.classList.add("text-base-content/50")
        this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }
}
