import { Controller } from "@hotwired/stimulus"

// Publishes the width of the visible viewport as --oc-viewport-width on the
// element (the body of the operations calendar). Unlike 100vw, the value
// excludes a classic always-visible vertical scrollbar, so parts pinned to the
// left while the page scrolls sideways (navbar, header, tabs) never run under
// it. The CSS falls back to 100vw until this has run.
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
    }

    disconnect() {
        this.observer.disconnect()
        window.removeEventListener("resize", this.update)
        this.element.style.removeProperty("--oc-viewport-width")
        this.element.style.removeProperty("--oc-navbar-height")
    }

    update() {
        this.element.style.setProperty("--oc-viewport-width", `${document.documentElement.clientWidth}px`)
        const navbar = document.querySelector(".app-navbar")
        if (navbar) this.element.style.setProperty("--oc-navbar-height", `${navbar.offsetHeight}px`)
    }
}
