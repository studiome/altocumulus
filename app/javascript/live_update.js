// Live updates. The server broadcasts a tiny signal (dates and "Model:id"
// keys, never patient data) and every open screen re-fetches what it shows
// with its own session. This module turns the signal into a window event and
// gives the screens one way to mark their own fetches as live.
//
// A live request carries `X-Live-Update: 1`; the server then does not count it
// as user activity, so an unattended screen still times out.
import { Turbo } from "@hotwired/turbo-rails"

export const LIVE_HEADER = "X-Live-Update"
export const LIVE_EVENT = "live-update"

// When the tab was hidden for at least this long, assume the socket missed
// signals (iPad Safari drops it while asleep) and refresh everything.
const HIDDEN_REFRESH_MS = 30000
const MARK_TTL_MS = 10000

const marked = new Map()

const key = (url) => {
  const absolute = new URL(url, window.location.href)
  absolute.hash = ""
  return absolute.href
}

// Remember that the next Turbo-made request to this URL is a live one (frame
// loads, frame.reload(), Turbo.visit). Returns the url for chaining.
export function markLive(url) {
  marked.set(key(url), Date.now() + MARK_TTL_MS)
  return url
}

// A plain fetch with the live header.
export function liveFetch(url, options = {}) {
  const headers = { ...(options.headers || {}), [LIVE_HEADER]: "1" }
  return fetch(url, { credentials: "same-origin", ...options, headers })
}

export function dispatchLiveUpdate({ dates = [], records = [], all = false } = {}) {
  window.dispatchEvent(new CustomEvent(LIVE_EVENT, { detail: { dates, records, all } }))
}

const words = (value) => (value || "").split(/\s+/).filter(Boolean)

Turbo.StreamActions.live_update = function () {
  dispatchLiveUpdate({
    dates: words(this.getAttribute("dates")),
    records: words(this.getAttribute("records")),
    all: this.getAttribute("all") === "true"
  })
}

document.addEventListener("turbo:before-fetch-request", (event) => {
  const url = event.detail.url
  if (!url) return

  const id = key(url)
  const until = marked.get(id)
  if (until === undefined) return

  marked.delete(id)
  if (until >= Date.now()) event.detail.fetchOptions.headers[LIVE_HEADER] = "1"
})

let hiddenAt = null
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "hidden") {
    hiddenAt = Date.now()
    return
  }
  const wasHiddenFor = hiddenAt === null ? 0 : Date.now() - hiddenAt
  hiddenAt = null
  if (wasHiddenFor >= HIDDEN_REFRESH_MS) dispatchLiveUpdate({ all: true })
})
