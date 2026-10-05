import { Controller } from "@hotwired/stimulus"

// Shows the purpose-specific fields of the hospitalization form. The server
// renders them already hidden or visible for the saved purpose; this only
// keeps them in step when the purpose select changes. Hidden fields stay in
// the DOM so their values are still submitted.
export default class extends Controller {
  static targets = [ "select", "otherSection", "surgerySection" ]

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
  }
}
