import { Controller } from "@hotwired/stimulus"

// Keyboard support for a tablist of links (role=tab, roving tabindex).
// Arrow keys / Home / End only move focus (manual activation): Enter follows
// the link, since each tab is a plain page link.
export default class extends Controller {
    keydown(event) {
        const tabs = Array.from(this.element.querySelectorAll('[role="tab"]'))
        const current = tabs.indexOf(document.activeElement)
        if (current === -1) return

        let next
        switch (event.key) {
            case "ArrowRight": next = (current + 1) % tabs.length; break
            case "ArrowLeft": next = (current - 1 + tabs.length) % tabs.length; break
            case "Home": next = 0; break
            case "End": next = tabs.length - 1; break
            default: return
        }

        event.preventDefault()
        tabs.forEach((tab, i) => tab.setAttribute("tabindex", i === next ? "0" : "-1"))
        tabs[next].focus()
    }
}
