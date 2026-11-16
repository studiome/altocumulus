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
    badge: { type: String, default: "Updated" },
    removed: String,         // "... %{count} ..."
    updated: String,         // "... %{count} ..."
    toastId: String,
    debounce: { type: Number, default: 400 },
    retry: { type: Number, default: 2000 }
  }

  connect() {
    this.pending = new Set()
    this.running = false
    this.refreshing = new Map()  // date => snapshot taken before the swap
    this.marked = new Map()      // date => Set of row keys carrying the marker
    this.offscreen = new Set()   // changed rows / bands outside the viewport
    this.toastCount = 0

    this.beforeStreamRender = (event) => this.wrapRender(event)
    this.pressed = (event) => this.clearMarker(event)
    document.addEventListener("turbo:before-stream-render", this.beforeStreamRender)
    this.element.addEventListener("pointerdown", this.pressed)
    this.bindToast()
  }

  disconnect() {
    clearTimeout(this.timer)
    clearTimeout(this.toastTimer)
    this.pending.clear()
    document.removeEventListener("turbo:before-stream-render", this.beforeStreamRender)
    this.element.removeEventListener("pointerdown", this.pressed)
    this.unbindToast()
    this.hideToast()
  }

  // ---- change highlighting -------------------------------------------------

  // Only streams this controller asked for (a day it is refreshing) are
  // diffed: day note / special slot editor streams for the same tbody are not.
  wrapRender(event) {
    const target = event.target.getAttribute && event.target.getAttribute("target")
    const date = target && target.startsWith("day-") ? target.slice(4) : null
    if (!date || !this.refreshing.has(date)) return

    const before = this.refreshing.get(date)
    this.refreshing.delete(date)
    const original = event.detail.render
    event.detail.render = async (stream) => {
      await original(stream)
      try { this.afterSwap(date, before) } catch (error) { console.error(error) }
    }
  }

  // key => { text, cells: { columnKey => text } } for the record rows of a day.
  snapshot(tbody) {
    const rows = new Map()
    tbody.querySelectorAll("tr[data-live-key]").forEach((row) => {
      const cells = {}
      row.querySelectorAll("td[data-ledger-column]").forEach((cell) => { cells[cell.dataset.ledgerColumn] = this.cellText(cell) })
      rows.set(row.dataset.liveKey, { cells, text: JSON.stringify(cells) })
    })
    return rows
  }

  cellText(cell) {
    const clone = cell.cloneNode(true)
    clone.querySelectorAll("[data-live-ignore]").forEach((node) => node.remove())
    return clone.textContent.replace(/\s+/g, " ").trim()
  }

  afterSwap(date, before) {
    const tbody = document.getElementById(`day-${date}`)
    if (!tbody) return

    const marked = this.marked.get(date) || new Set()
    const changed = []
    const present = new Set()

    tbody.querySelectorAll("tr[data-live-key]").forEach((row) => {
      const key = row.dataset.liveKey
      present.add(key)
      const old = before.get(key)
      if (!old) {
        changed.push(row)
        marked.add(key)
        row.classList.add("live-changed")
      } else {
        const cells = {}
        row.querySelectorAll("td[data-ledger-column]").forEach((cell) => { cells[cell.dataset.ledgerColumn] = this.cellText(cell) })
        if (JSON.stringify(cells) !== old.text) {
          changed.push(row)
          marked.add(key)
          row.classList.add("live-changed")
          row.querySelectorAll("td[data-ledger-column]").forEach((cell) => {
            if (old.cells[cell.dataset.ledgerColumn] !== cells[cell.dataset.ledgerColumn]) cell.classList.add("live-changed-cell")
          })
        }
      }
    })

    // Markers survive later swaps of the day; rows that are gone lose theirs.
    Array.from(marked).forEach((key) => { if (!present.has(key)) marked.delete(key) })
    if (marked.size > 0) this.marked.set(date, marked)
    else this.marked.delete(date)
    tbody.querySelectorAll("tr[data-live-key]").forEach((row) => {
      if (marked.has(row.dataset.liveKey)) this.mark(row)
    })

    const removed = Array.from(before.keys()).filter((key) => !present.has(key)).length
    const notable = [...changed]
    if (removed > 0) {
      const band = this.removalBand(tbody, removed)
      if (band) notable.push(band)
    }
    this.notifyOffscreen(notable)
  }

  mark(row) {
    row.classList.add("live-marked")
    if (row.querySelector(".live-badge")) return
    const cell = row.querySelector("td:not(.ledger-day)")
    if (!cell) return
    const badge = document.createElement("span")
    badge.className = "badge badge-warning badge-xs live-badge print:hidden"
    badge.setAttribute("data-live-ignore", "")
    badge.textContent = this.badgeValue
    cell.classList.add("live-marker-cell")
    cell.prepend(badge)
  }

  clearMarker(event) {
    const row = event.target.closest && event.target.closest("tr.live-marked")
    if (!row) return

    row.classList.remove("live-marked", "live-changed")
    row.querySelectorAll(".live-badge").forEach((badge) => badge.remove())
    row.querySelectorAll(".live-marker-cell").forEach((cell) => cell.classList.remove("live-marker-cell"))
    const tbody = row.closest("tbody")
    const keys = tbody && this.marked.get(tbody.id.slice(4))
    if (keys) keys.delete(row.dataset.liveKey)
  }

  removalBand(tbody, count) {
    const columns = this.element.querySelectorAll("thead th").length || 1
    const row = document.createElement("tr")
    row.className = "ledger-band live-removed-band print:hidden"
    row.setAttribute("role", "status")
    row.setAttribute("data-live-ignore", "")
    const cell = document.createElement("td")
    cell.colSpan = columns
    const content = document.createElement("div")
    content.className = "ledger-band-content"
    content.textContent = this.removedValue.replace("%{count}", count)
    cell.append(content)
    row.append(cell)

    const anchor = tbody.querySelector("tr[data-live-key], tr.oc-empty")
    if (anchor) tbody.insertBefore(row, anchor)
    else tbody.append(row)
    setTimeout(() => row.remove(), 10000)
    return row
  }

  // ---- off-screen notice ---------------------------------------------------

  notifyOffscreen(elements) {
    const height = window.innerHeight || document.documentElement.clientHeight
    const hidden = elements.filter((element) => {
      const rect = element.getBoundingClientRect()
      return rect.bottom < 0 || rect.top > height
    })
    if (hidden.length === 0) return

    hidden.forEach((element) => this.offscreen.add(element))
    this.toastCount += hidden.length
    this.showToast()
  }

  get toast() { return this.hasToastIdValue ? document.getElementById(this.toastIdValue) : null }

  bindToast() {
    const toast = this.toast
    if (!toast) return
    this.goButton = toast.querySelector("[data-live-toast-go]")
    this.closeButton = toast.querySelector("[data-live-toast-close]")
    this.go = () => this.scrollToFirst()
    this.close = () => this.hideToast()
    this.goButton && this.goButton.addEventListener("click", this.go)
    this.closeButton && this.closeButton.addEventListener("click", this.close)
  }

  unbindToast() {
    this.goButton && this.goButton.removeEventListener("click", this.go)
    this.closeButton && this.closeButton.removeEventListener("click", this.close)
  }

  showToast() {
    const toast = this.toast
    if (!toast) return
    const message = toast.querySelector("[data-live-toast-message]")
    if (message) message.textContent = this.updatedValue.replace("%{count}", this.toastCount)
    toast.style.display = "flex"
    clearTimeout(this.toastTimer)
    this.toastTimer = setTimeout(() => this.hideToast(), 20000)
  }

  hideToast() {
    clearTimeout(this.toastTimer)
    this.offscreen.clear()
    this.toastCount = 0
    const toast = this.toast
    if (toast) toast.style.display = "none"
  }

  scrollToFirst() {
    const live = Array.from(this.offscreen).filter((element) => element.isConnected)
    live.sort((a, b) => (a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1))
    if (live[0]) live[0].scrollIntoView({ block: "center" })
    this.hideToast()
  }

  // ---- fetching ------------------------------------------------------------

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
      const tbody = document.getElementById(`day-${date}`)
      if (tbody) this.refreshing.set(date, this.snapshot(tbody))
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
