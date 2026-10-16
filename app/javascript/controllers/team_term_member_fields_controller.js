import { Controller } from "@hotwired/stimulus"

// Add/remove rows of a team term's member list. Rows the server rendered are
// only hidden (and their _destroy field set), so nested attributes still
// delete them; rows added client-side are simply dropped again.
export default class extends Controller {
    static targets = ["list", "template", "item", "destroyField", "nameField"]

    connect() {
        // Rails' params.expect only treats purely numeric keys as nested-attribute
        // indices, so new rows need a numeric-only, monotonically increasing index.
        this.nextIndex = Date.now()
        this.itemTargets.forEach((item) => {
            if (item.querySelector("[data-team-term-member-fields-target='destroyField']")?.value === "1") {
                item.hidden = true
            }
        })
    }

    add() {
        const content = this.templateTarget.innerHTML.replaceAll(/NEW_RECORD/g, `${this.nextIndex++}`)
        this.listTarget.insertAdjacentHTML("beforeend", content)
    }

    remove(event) {
        const item = event.currentTarget.closest("[data-team-term-member-fields-target='item']")
        const destroyField = item?.querySelector("[data-team-term-member-fields-target='destroyField']")

        if (destroyField && item.querySelector("input[name$='[id]']")) {
            destroyField.value = "1"
            item.hidden = true
        } else {
            item?.remove()
        }
    }

    // Choosing a user fills in a still-empty name with the user's name, which
    // the server would do anyway; this just shows it.
    userChanged(event) {
        const select = event.currentTarget
        const nameField = select.closest("[data-team-term-member-fields-target='item']")
            ?.querySelector("[data-team-term-member-fields-target='nameField']")
        if (!nameField || nameField.value.trim() !== "" || select.value === "") return

        nameField.value = select.selectedOptions[0].textContent
    }
}
