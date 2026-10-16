import { Controller } from "@hotwired/stimulus"

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
    slotSummaryUrl: String, teamMembersUrl: String
  }

  connect() {
    this.toggleTransfer()
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

  load(frame, path, params) {
    const url = new URL(path, window.location.origin)
    Object.entries(params).forEach(([key, value]) => url.searchParams.set(key, value))
    frame.src = url.toString()
  }
}
