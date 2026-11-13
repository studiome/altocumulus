import { Controller } from "@hotwired/stimulus"

// Publishes the width of the visible viewport as --oc-viewport-width on the
// element (the body of the operations calendar). Unlike 100vw, the value
// excludes a classic always-visible vertical scrollbar, so parts pinned to the
// left while the page scrolls sideways (navbar, header, tabs) never run under
// it. The CSS falls back to 100vw until this has run.
//
// iOS Safari zooms a wider-than-screen page out to fit: what is visible (the
// visual viewport) is then wider than the layout width the page was laid out
// for, and a bar sized to the layout width stops short of the screen edge. So
// the wider of the two is published. Zoomed in, the visual viewport is the
// smaller one and the layout width still applies.
export default class extends Controller {
    connect() {
        this.update = this.update.bind(this)
        this.update()
        this.observer = new ResizeObserver(this.update)
        this.observer.observe(document.documentElement)
        // The navbar is fixed on this page: its height becomes the body's top padding.
        const navbar = document.querySelector(".app-navbar")
        if (navbar) this.observer.observe(navbar)
        window.addEventListener("resize", this.update)
        window.visualViewport?.addEventListener("resize", this.update)
    }

    disconnect() {
        this.observer.disconnect()
        window.removeEventListener("resize", this.update)
        window.visualViewport?.removeEventListener("resize", this.update)
        this.element.style.removeProperty("--oc-viewport-width")
        this.element.style.removeProperty("--oc-navbar-height")
    }

    update() {
        this.element.style.setProperty("--oc-viewport-width", `${this.visibleWidth()}px`)
        const navbar = document.querySelector(".app-navbar")
        if (navbar) this.element.style.setProperty("--oc-navbar-height", `${navbar.offsetHeight}px`)
    }

    visibleWidth() {
        const layout = document.documentElement.clientWidth
        const visual = Math.floor(window.visualViewport?.width || 0)
        return Math.max(layout, visual)
    }
}
