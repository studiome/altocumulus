import { Controller } from "@hotwired/stimulus"

// Keyboard movement out of the login ID field.
// Safari (Mac and iPadOS) does not reliably move focus from the ID field with
// Tab, so the controller moves it to the password field explicitly.
// Enter moves on instead of submitting an empty password.
export default class extends Controller {
    static targets = ["loginId", "password"]

    keydown(event) {
        // Enter/Tab that confirms an IME conversion must never count.
        if (event.isComposing || event.keyCode === 229) return

        if (event.key === "Tab") {
            // Shift+Tab and modified Tab keep the browser default.
            if (event.shiftKey || event.altKey || event.ctrlKey || event.metaKey) return
            event.preventDefault()
            this.passwordTarget.focus()
        } else if (event.key === "Enter") {
            // A filled password (e.g. by a password manager): submit as usual.
            if (this.passwordTarget.value !== "") return
            event.preventDefault()
            this.passwordTarget.focus()
        }
    }
}
