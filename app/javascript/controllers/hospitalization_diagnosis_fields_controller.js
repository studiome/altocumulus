import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["list", "template", "item", "destroyField", "addButton"]
    static values = {
        maxItems: Number
    }

    connect() {
        this.hideDestroyedItems()
        this.refreshAddButtonState()
        // Rails' params.expect only treats purely numeric keys as nested-attribute
        // indices (see ActionController::Parameters.nested_attribute?), so new rows
        // need a numeric-only, monotonically increasing index to survive submission.
        this.nextIndex = Date.now()
    }

    hideDestroyedItems() {
        this.itemTargets.forEach((item) => {
            const destroyField = item.querySelector("[data-hospitalization-diagnosis-fields-target='destroyField']")
            if (destroyField && destroyField.value === "1") {
                item.hidden = true
            }
        })
    }

    add() {
        if (this.activeItems.length >= this.maxItemsValue) return

        const content = this.templateTarget.innerHTML.replaceAll(/NEW_RECORD/g, `${this.nextIndex++}`)
        this.listTarget.insertAdjacentHTML("beforeend", content)
        this.refreshAddButtonState()
    }

    remove(event) {
        const item = event.currentTarget.closest("[data-hospitalization-diagnosis-fields-target='item']")
        const destroyField = item?.querySelector("[data-hospitalization-diagnosis-fields-target='destroyField']")

        if (destroyField) {
            destroyField.value = "1"
            item.hidden = true
        } else {
            item?.remove()
        }

        this.refreshAddButtonState()
    }

    refreshAddButtonState() {
        if (!this.hasAddButtonTarget) return

        this.addButtonTarget.disabled = this.activeItems.length >= this.maxItemsValue
    }

    get activeItems() {
        return this.itemTargets.filter((item) => {
            const destroyField = item.querySelector("[data-hospitalization-diagnosis-fields-target='destroyField']")
            return !item.hidden && destroyField?.value !== "1"
        })
    }
}
