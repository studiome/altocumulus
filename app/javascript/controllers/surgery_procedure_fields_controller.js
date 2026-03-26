import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["list", "template", "item", "destroyField", "addButton"]
    static values = {
        maxItems: Number
    }

    connect() {
        this.refreshAddButtonState()
    }

    add() {
        if (this.activeItems.length >= this.maxItemsValue) return

        const content = this.templateTarget.innerHTML.replaceAll(/NEW_RECORD/g, `${Date.now()}-${Math.random().toString(36).slice(2)}`)
        this.listTarget.insertAdjacentHTML("beforeend", content)
        this.refreshAddButtonState()
    }

    remove(event) {
        const item = event.currentTarget.closest("[data-surgery-procedure-fields-target='item']")
        const destroyField = item?.querySelector("[data-surgery-procedure-fields-target='destroyField']")

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
            const destroyField = item.querySelector("[data-surgery-procedure-fields-target='destroyField']")
            return !item.hidden && destroyField?.value !== "1"
        })
    }
}