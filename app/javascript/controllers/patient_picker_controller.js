import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["input", "display"]
    static values = { placeholder: String }

    select(event) {
        const { id, label } = event.detail

        this.inputTarget.value = id
        this.displayTarget.textContent = label
        this.displayTarget.classList.remove("text-base-content/50")
        this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }

    clear() {
        this.inputTarget.value = ""
        this.displayTarget.textContent = this.placeholderValue
        this.displayTarget.classList.add("text-base-content/50")
        this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }
}
