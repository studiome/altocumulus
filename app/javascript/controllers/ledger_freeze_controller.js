import { Controller } from "@hotwired/stimulus"

// Sets --oc-freeze-<key> on the ledger table for every frozen header cell
// (th[data-freeze-key]): the width of the day column plus the frozen columns
// before it. Cells use it as their sticky `left`, so the columns up to the
// patient column stay in view while the page scrolls sideways. The variables
// live on the table, so a day re-rendered by turbo stream keeps them; the
// widths are re-measured whenever the table resizes.
export default class extends Controller {
    connect() {
        this.update = this.update.bind(this)
        this.update()
        this.observer = new ResizeObserver(this.update)
        this.observer.observe(this.element)
    }

    disconnect() {
        this.observer.disconnect()
        this.keys().forEach((key) => this.element.style.removeProperty(`--oc-freeze-${key}`))
    }

    keys() {
        return Array.from(this.element.querySelectorAll("thead th[data-freeze-key]")).map((th) => th.dataset.freezeKey)
    }

    update() {
        const headers = Array.from(this.element.querySelectorAll("thead th"))
        let left = 0
        for (const th of headers) {
            const key = th.dataset.freezeKey
            if (key) this.element.style.setProperty(`--oc-freeze-${key}`, `${left}px`)
            else if (th !== headers[0]) break
            left += th.getBoundingClientRect().width
        }
    }
}
