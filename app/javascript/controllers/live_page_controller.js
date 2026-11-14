import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { markLive } from "live_update"

// Refreshes the page it sits on when another user changes what it shows.
//   - A show page names its records ("Patient:3 Hospitalization:7"): it
//     refreshes when a live-update event names one of them.
//   - A list page names record types ("Surgery Patient"): a new record is not
//     on the page yet and cannot be matched by id, so any record of such a type
//     refreshes it.
// `all` events refresh either. The refresh is a Turbo morph of the current URL
// (the page's meta tags ask for morphing and a preserved scroll), so filters,
// sorting and the page number stay as the URL has them.
//
// Bursts cause one refresh and refreshes are at most `minInterval` apart. It
// waits while a dialog is open or a form field has focus, and keeps whatever
// the user typed into a field but did not submit (the morph skips such fields).
export default class extends Controller {
  static values = {
    records: String,
    types: String,
    debounce: { type: Number, default: 300 },
    minInterval: { type: Number, default: 2000 },
    retry: { type: Number, default: 1000 }
  }

  connect() {
    this.dirty = false
    this.lastRefresh = 0
    this.keepTypedValues = (event) => {
      const element = event.target
      if (element instanceof HTMLElement && this.userChanged(element)) event.preventDefault()
    }
    document.addEventListener("turbo:before-morph-element", this.keepTypedValues)
  }

  disconnect() {
    clearTimeout(this.timer)
    document.removeEventListener("turbo:before-morph-element", this.keepTypedValues)
  }

  received(event) {
    const { records = [], all = false } = event.detail || {}
    if (!all && !records.some((key) => this.relevant(key))) return

    this.dirty = true
    this.schedule()
  }

  relevant(key) {
    return this.words(this.recordsValue).includes(key) || this.words(this.typesValue).includes(key.split(":")[0])
  }

  words(value) {
    return value.split(/\s+/).filter(Boolean)
  }

  schedule(minimum = this.debounceValue) {
    clearTimeout(this.timer)
    const sinceLast = Date.now() - this.lastRefresh
    this.timer = setTimeout(() => this.refresh(), Math.max(minimum, this.minIntervalValue - sinceLast))
  }

  refresh() {
    if (!this.dirty) return
    if (this.busy()) return this.schedule(this.retryValue)

    this.dirty = false
    this.lastRefresh = Date.now()
    markLive(window.location.href)
    Turbo.visit(window.location.href, { action: "replace" })
  }

  // Something the user is in the middle of: an open dialog, a focused field.
  busy() {
    if (document.querySelector("dialog[open]")) return true

    const active = document.activeElement
    return Boolean(active && active.matches("input:not([type=button]):not([type=submit]):not([type=checkbox]):not([type=radio]), textarea, select, [contenteditable]"))
  }

  // A field the user typed in or changed since the page was rendered.
  userChanged(element) {
    if (element instanceof HTMLTextAreaElement) return element.value !== element.defaultValue
    if (element instanceof HTMLSelectElement) return Array.from(element.options).some((option) => option.selected !== option.defaultSelected)
    if (element instanceof HTMLInputElement) {
      if (element.type === "checkbox" || element.type === "radio") return element.checked !== element.defaultChecked
      if (element.type === "hidden" || element.type === "submit" || element.type === "button") return false
      return element.value !== element.defaultValue
    }
    return false
  }
}
