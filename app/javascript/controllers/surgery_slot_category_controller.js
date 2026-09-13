import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "categoryRadio",
    "slotNumberSection",
    "targetDepartmentSection",
    "locationSection",
    "schedulingTypeRadio"
  ]

  connect() {
    this.toggle()
  }

  toggle() {
    const selectedCategory = this.selectedCategoryValue
    const isEmergency = this.isEmergencySelected

    // Slot number is only relevant for regular elective slots
    if (this.hasSlotNumberSectionTarget) {
      const showSlotNumber = selectedCategory === "regular" && !isEmergency
      this.slotNumberSectionTarget.classList.toggle("hidden", !showSlotNumber)
    }

    // Target department is relevant for simultaneous / backup
    if (this.hasTargetDepartmentSectionTarget) {
      const showTargetDept = selectedCategory === "simultaneous" || selectedCategory === "backup"
      this.targetDepartmentSectionTarget.classList.toggle("hidden", !showTargetDept)
    }

    // Location is relevant for off_slot (procedure room, catheter lab, etc.)
    if (this.hasLocationSectionTarget) {
      const showLocation = selectedCategory === "off_slot"
      this.locationSectionTarget.classList.toggle("hidden", !showLocation)
    }
  }

  get selectedCategoryValue() {
    const checkedRadio = this.categoryRadioTargets.find(radio => radio.checked)
    return checkedRadio ? checkedRadio.value : "regular"
  }

  get isEmergencySelected() {
    if (!this.hasSchedulingTypeRadioTarget) return false
    const checkedRadio = this.schedulingTypeRadioTargets.find(radio => radio.checked)
    return checkedRadio ? checkedRadio.value === "emergency" : false
  }
}
