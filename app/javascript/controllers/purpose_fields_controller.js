import { Controller } from "@hotwired/stimulus"

// Shows the purpose-specific fields of the hospitalization form. The server
// renders them already hidden or visible for the saved purpose; this only
// keeps them in step when the purpose select changes. Hidden fields stay in
// the DOM so their values are still submitted.
export default class extends Controller {
  static targets = [ "select", "otherSection", "surgerySection", "procedureSection", "requiredLabel" ]

  connect() {
    this.toggle()
  }

  toggle() {
    if (this.hasOtherSectionTarget) {
      this.otherSectionTarget.classList.toggle("hidden", this.selectTarget.value !== "other")
    }
    if (this.hasSurgerySectionTarget) {
      this.surgerySectionTarget.classList.toggle("hidden", this.selectTarget.value !== "surgery")
    }
    if (this.hasProcedureSectionTarget) {
      this.procedureSectionTarget.classList.toggle("hidden", this.selectTarget.value === "surgery")
    }
    // A label whose field the site requires only for some purposes carries
    // those purposes in data-required-purposes.
    this.requiredLabelTargets.forEach((label) => {
      const purposes = (label.dataset.requiredPurposes || "").split(" ")
      label.classList.toggle("app-field-label-required", purposes.includes(this.selectTarget.value))
    })
  }
}
