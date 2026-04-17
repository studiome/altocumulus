import { Controller } from "@hotwired/stimulus"

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