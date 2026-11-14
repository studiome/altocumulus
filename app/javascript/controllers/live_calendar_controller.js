import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { liveFetch } from "live_update"

// Keeps the days of the operations calendar current. On a live-update event
// it re-fetches each affected day (the server renders it for this viewer with
// the calendar's own filters) and swaps that day's <tbody> in as a turbo
// stream. No morphing: ledger-freeze keeps measured offsets as CSS variables
// on the table, which a day swap leaves alone.
//
// A day whose editor is open (a form inside it, or focus inside it) is kept
// pending and retried, so typing is never lost.
export default class extends Controller {
  static values = {
    dayUrl: String,          // calendar_day_path with the placeholder DATE
    context: Object,         // start, days, view, mine, team_id
    debounce: { type: Number, default: 400 },
    retry: { type: Number, default: 2000 }
  }

  connect() {
    this.pending = new Set()
    this.running = false
  }

  disconnect() {
    clearTimeout(this.timer)
    this.pending.clear()
  }

  received(event) {
    const { dates = [], all = false } = event.detail || {}
    const visible = this.visibleDates()

    if (all) visible.forEach((date) => this.pending.add(date))
    else dates.filter((date) => visible.includes(date)).forEach((date) => this.pending.add(date))

    if (this.pending.size > 0) this.schedule(this.debounceValue)
  }

  visibleDates() {
    return Array.from(this.element.querySelectorAll("tbody[id^='day-']")).map((tbody) => tbody.id.slice(4))
  }

  schedule(delay) {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.flush(), delay)
  }

  async flush() {
    if (this.running) return this.schedule(this.debounceValue)

    this.running = true
    let blocked = false
    try {
      for (const date of Array.from(this.pending)) {
        const tbody = document.getElementById(`day-${date}`)
        if (!tbody) {
          this.pending.delete(date)
        } else if (this.editing(tbody)) {
          blocked = true
        } else {
          this.pending.delete(date)
          const ok = await this.refreshDay(date)
          if (!ok) break
        }
      }
    } finally {
      this.running = false
    }
    if (this.pending.size > 0) this.schedule(blocked ? this.retryValue : this.debounceValue)
  }

  editing(tbody) {
    if (tbody.querySelector("form")) return true

    const active = document.activeElement
    return Boolean(active && tbody.contains(active) && active.matches("input, textarea, select, [contenteditable]"))
  }

  // false stops the run (the session is gone and the page is navigating).
  async refreshDay(date) {
    const url = new URL(this.dayUrlValue.replace("DATE", date), window.location.origin)
    Object.entries(this.contextValue || {}).forEach(([name, value]) => {
      if (value !== null && value !== undefined && value !== "") url.searchParams.set(name, value)
    })

    let response
    try {
      response = await liveFetch(url, { headers: { Accept: "text/vnd.turbo-stream.html" } })
    } catch (_error) {
      return true // offline: the next signal or the visibility refresh retries
    }

    const type = response.headers.get("Content-Type") || ""
    if (response.ok && type.includes("turbo-stream")) {
      Turbo.renderStreamMessage(await response.text())
      return true
    }
    if (response.redirected || type.includes("text/html")) {
      // Signed out meanwhile: a normal visit lands on the sign-in page.
      Turbo.visit(window.location.href)
      return false
    }
    return true
  }
}
