import { Controller } from "@hotwired/stimulus"

// On an open edit form: when a live-update event names one of the records the
// form edits, reveal a non-blocking notice ("Another user has just updated
// this record") with a link to load the latest. It never touches the inputs
// and never reloads by itself; the save itself asks before overwriting (see
// EditConflictGuard). `all` events do not raise it.
export default class extends Controller {
  static targets = [ "notice" ]
  static values = { records: String }

  received(event) {
    if (!this.hasNoticeTarget) return

    const watched = this.recordsValue.split(/\s+/).filter(Boolean)
    const records = (event.detail && event.detail.records) || []
    if (records.some((key) => watched.includes(key))) this.noticeTarget.classList.remove("hidden")
  }
}
