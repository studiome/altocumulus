import { Controller } from "@hotwired/stimulus"
import { markLive } from "live_update"

// The live parts of the reservation form. Each one is a small turbo-frame
// that is re-fetched from the server when the input it depends on changes:
//   - the patient confirmation card (when the picked patient changes)
//   - the number of admissions already scheduled on the admission date, and
//     the side panel's month calendar (when the admission date changes)
//   - the slot summary of the surgery date
//   - the team members of the term covering the relevant date
// Setting a frame's `src` makes Turbo load it. Also keeps the transfer source
// department select enabled only while a transfer status is chosen.
export default class extends Controller {
  static targets = [
    "patientInput", "patientFrame", "admissionDate", "admissionCountFrame", "calendarFrame",
    "surgeryDate", "slotFrame", "procedureDate", "team", "teamFrame",
    "transferRadio", "sourceDepartment"
  ]
  static values = {
    patientCardUrl: String, admissionCountUrl: String, admissionCalendarUrl: String,
    slotSummaryUrl: String, teamMembersUrl: String,
    followSurgeryDate: Boolean, admissionDaysBeforeSurgery: { type: Number, default: 1 }
  }

  connect() {
    this.toggleTransfer()
    this.admissionEdited = this.admissionDiffersFromSurgery()
  }

  // A new form's admission date follows the surgery date (surgery date minus
  // the site's admission_days_before_surgery) until the admission date is
  // edited by hand.
  surgeryDateChanged() {
    this.refreshSlot()
    this.refreshTeam()
    if (!this.followSurgeryDateValue || this.admissionEdited) return
    if (!this.hasAdmissionDateTarget || !this.hasSurgeryDateTarget) return

    const suggested = this.suggestedAdmissionDate()
    if (!suggested) return

    this.admissionDateTarget.value = suggested
    this.refreshAdmission()
    this.refreshTeam()
  }

  // Fired by the user's own input on the admission date field; setting
  // `value` from here does not fire it.
  admissionEditedByUser() {
    this.admissionEdited = true
  }

  suggestedAdmissionDate() {
    const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(this.hasSurgeryDateTarget ? this.surgeryDateTarget.value : "")
    if (!match) return null

    const date = new Date(Date.UTC(+match[1], +match[2] - 1, +match[3] - this.admissionDaysBeforeSurgeryValue))
    return date.toISOString().slice(0, 10)
  }

  // A field that already holds something other than the suggestion (an
  // explicit date from the link, an edited reservation) is not overwritten.
  admissionDiffersFromSurgery() {
    if (!this.hasAdmissionDateTarget) return false

    const current = this.admissionDateTarget.value
    return current !== "" && current !== this.suggestedAdmissionDate()
  }

  refreshPatient() {
    if (!this.hasPatientFrameTarget) return

    this.load(this.patientFrameTarget, this.patientCardUrlValue, { patient_id: this.patientInputTarget.value })
  }

  refreshAdmission() {
    const date = this.admissionDateTarget.value

    if (this.hasAdmissionCountFrameTarget) {
      this.load(this.admissionCountFrameTarget, this.admissionCountUrlValue, { date })
    }
    if (this.hasCalendarFrameTarget) {
      this.load(this.calendarFrameTarget, this.admissionCalendarUrlValue, { month: date.slice(0, 7), selected: date })
    }
  }

  refreshSlot() {
    if (!this.hasSlotFrameTarget || !this.hasSurgeryDateTarget) return

    this.load(this.slotFrameTarget, this.slotSummaryUrlValue, { date: this.surgeryDateTarget.value })
  }

  // The members shown are those of the term covering the surgery date, else
  // the procedure date, else the admission date.
  refreshTeam() {
    if (!this.hasTeamTarget || !this.hasTeamFrameTarget) return

    this.load(this.teamFrameTarget, this.teamMembersUrlValue, { team_id: this.teamTarget.value, date: this.teamDate })
  }

  toggleTransfer() {
    if (!this.hasSourceDepartmentTarget) return

    const selected = this.transferRadioTargets.find((radio) => radio.checked)?.value || "none"
    this.sourceDepartmentTarget.disabled = selected === "none"
  }

  get teamDate() {
    const applies = (input) => input && !input.disabled && input.value
    const surgeryDate = this.hasSurgeryDateTarget ? this.surgeryDateTarget : null
    const procedureDate = this.hasProcedureDateTarget ? this.procedureDateTarget : null

    if (applies(surgeryDate)) return surgeryDate.value
    if (applies(procedureDate)) return procedureDate.value
    return this.hasAdmissionDateTarget ? this.admissionDateTarget.value : ""
  }

  // Another user changed something (see live_update.js): reload the live
  // parts that show a date in the signal. Only the frames are touched, never
  // the user's inputs, and the side calendar stays on the month the user
  // navigated to.
  liveUpdate(event) {
    const { dates = [], all = false } = event.detail || {}
    const named = (date) => Boolean(date) && (all || dates.includes(date))

    if (this.hasSlotFrameTarget && this.hasSurgeryDateTarget && named(this.surgeryDateTarget.value)) {
      this.load(this.slotFrameTarget, this.slotSummaryUrlValue, { date: this.surgeryDateTarget.value }, { live: true })
    }

    if (!this.hasAdmissionDateTarget) return

    const admissionDate = this.admissionDateTarget.value
    if (this.hasAdmissionCountFrameTarget && named(admissionDate)) {
      this.load(this.admissionCountFrameTarget, this.admissionCountUrlValue, { date: admissionDate }, { live: true })
    }

    if (this.hasCalendarFrameTarget) {
      const month = this.shownMonth()
      if (all || (month && dates.some((date) => date.slice(0, 7) === month))) {
        this.load(this.calendarFrameTarget, this.admissionCalendarUrlValue, { month, selected: admissionDate }, { live: true })
      }
    }
  }

  // The month the side calendar shows: the one in its current src (the user
  // may have paged to another), else the admission date's.
  shownMonth() {
    const fromSrc = this.hasCalendarFrameTarget && this.calendarFrameTarget.src
      ? new URL(this.calendarFrameTarget.src).searchParams.get("month")
      : null
    return fromSrc || (this.hasAdmissionDateTarget ? this.admissionDateTarget.value.slice(0, 7) : "")
  }

  // Assigning the src a frame already has does not reload it, so an equal src
  // reloads explicitly. `live` marks the request as made by a live update.
  load(frame, path, params, { live = false } = {}) {
    const url = new URL(path, window.location.origin)
    Object.entries(params).forEach(([key, value]) => url.searchParams.set(key, value))
    const target = url.toString()
    if (live) markLive(target)

    if (frame.src === target) frame.reload()
    else frame.src = target
  }
}
