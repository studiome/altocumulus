import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["list", "template", "item", "destroyField", "addButton"]
    static values = {
        maxItems: Number
    }

    connect() {
        this.hideDestroyedItems()
        this.refreshAddButtonState()
    }

    hideDestroyedItems() {
        this.itemTargets.forEach((item) => {
            const destroyField = item.querySelector("[data-surgery-procedure-fields-target='destroyField']")
            if (destroyField && destroyField.value === "1") {
                item.hidden = true
            }
        })
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

    addProcedureOption(event) {
        const { id, name } = event.detail

        this.element.querySelectorAll(".surgery-procedure-select").forEach((select) => {
            if (!Array.from(select.options).some(opt => opt.value === id.toString())) {
                const opt = document.createElement("option")
                opt.value = id
                opt.textContent = name
                select.appendChild(opt)
            }
            if (select.value === "") {
                select.value = id
            }
        })

        if (this.hasTemplateTarget) {
            const templateContent = this.templateTarget.content
            const select = templateContent.querySelector(".surgery-procedure-select")
            if (select && !Array.from(select.options).some(opt => opt.value === id.toString())) {
                const opt = document.createElement("option")
                opt.value = id
                opt.textContent = name
                select.appendChild(opt)
            }
        }
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