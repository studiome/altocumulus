import { Controller } from "@hotwired/stimulus"

// Shows the purpose-specific fields of the hospitalization form. The server
// renders them already hidden or visible for the saved purpose; this only
// keeps them in step when the purpose select changes. By default hidden
// fields stay enabled so their values are still submitted. With
// data-purpose-fields-disable-hidden-value="true" (the reservation form) the
// inputs of the surgery / procedure sections are disabled while hidden, so a
// section that does not apply to the purpose is not submitted at all.
export default class extends Controller {
  static targets = [ "select", "otherSection", "surgerySection", "procedureSection", "requiredLabel" ]
  static values = { disableHidden: Boolean }

  connect() {
    this.toggle()
  }

  toggle() {
    const purpose = this.selectTarget.value

    if (this.hasOtherSectionTarget) {
      this.otherSectionTarget.classList.toggle("hidden", purpose !== "other")
    }
    if (this.hasSurgerySectionTarget) {
      this.setVisible(this.surgerySectionTarget, purpose === "surgery")
    }
    if (this.hasProcedureSectionTarget) {
      this.setVisible(this.procedureSectionTarget, purpose !== "surgery")
    }
    // A label whose field the site requires only for some purposes carries
    // those purposes in data-required-purposes.
    this.requiredLabelTargets.forEach((label) => {
      const purposes = (label.dataset.requiredPurposes || "").split(" ")
      label.classList.toggle("app-field-label-required", purposes.includes(purpose))
    })
  }

  setVisible(section, visible) {
    section.classList.toggle("hidden", !visible)
    if (!this.disableHiddenValue) return

    section.querySelectorAll("input, select, textarea").forEach((control) => {
      control.disabled = !visible
    })
  }
}
