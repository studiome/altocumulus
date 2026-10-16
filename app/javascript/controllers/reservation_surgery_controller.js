import { Controller } from "@hotwired/stimulus"

// The surgery section of the reservation form: which fields apply to the
// chosen slot category, and whether the performing-department select is
// offered for the chosen location.
//   - partner department: simultaneous / backup
//   - backup intervention: backup
//   - location (+ performing department when the location asks for one):
//     regular / off-slot (a partner department's slot has no room of ours)
//   - slot number: regular slots of an elective case
export default class extends Controller {
  static targets = [
    "categoryRadio", "schedulingTypeRadio", "partnerSection", "interventionSection",
    "locationSection", "locationSelect", "performingSection", "slotNumberSection"
  ]

  connect() {
    this.toggle()
  }

  toggle() {
    const category = this.category
    const partnerSlot = category === "simultaneous" || category === "backup"

    this.show(this.partnerSectionTargets, partnerSlot)
    this.show(this.interventionSectionTargets, category === "backup")
    this.show(this.locationSectionTargets, !partnerSlot)
    this.show(this.slotNumberSectionTargets, category === "regular" && !this.emergency)
    this.show(this.performingSectionTargets, !partnerSlot && this.locationAsksPerformingDepartment)
  }

  show(elements, visible) {
    elements.forEach((element) => element.classList.toggle("hidden", !visible))
  }

  get category() {
    return this.categoryRadioTargets.find((radio) => radio.checked)?.value || "regular"
  }

  get emergency() {
    return this.schedulingTypeRadioTargets.find((radio) => radio.checked)?.value === "emergency"
  }

  get locationAsksPerformingDepartment() {
    if (!this.hasLocationSelectTarget) return false

    const option = this.locationSelectTarget.selectedOptions[0]
    return option?.dataset.asksPerformingDepartment === "true"
  }
}
