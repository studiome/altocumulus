import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    connect() {
        const dialog = this.element.closest("dialog")

        if (dialog?.open) {
            dialog.close()
        }
    }
}