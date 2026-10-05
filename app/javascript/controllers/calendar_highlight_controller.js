import { Controller } from "@hotwired/stimulus"

// Put on the operations calendar's day that was just saved: scrolls it into
// view, then drops the highlight class after a moment so the colour fades out
// (the fade itself is the CSS transition on the day's cells).
export default class extends Controller {
    connect() {
        this.element.scrollIntoView({ block: "center" })
        this.timeout = setTimeout(() => this.element.classList.remove("oc-day-highlight"), 2500)
    }

    disconnect() {
        clearTimeout(this.timeout)
    }
}
