import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    connect() {
        this.timeout = setTimeout(() => this.dismiss(), 3000)
    }

    disconnect() {
        clearTimeout(this.timeout)
        clearTimeout(this.dismissTimeout)
    }

    dismiss() {
        this.element.style.transition = "opacity 0.4s ease"
        this.element.style.opacity = "0"
        this.dismissTimeout = setTimeout(() => this.element.remove(), 400)
    }
}
