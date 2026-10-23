import { Controller } from "@hotwired/stimulus"

// The "Expand" link on an activity row: shows the hidden row below it, whose lazy
// turbo-frame then loads the bill's shares.
export default class extends Controller {
  toggle(event) {
    event.preventDefault()
    const row = this.element.closest("tr").nextElementSibling
    const show = row.style.display === "none"
    row.style.display = show ? "" : "none"
    this.element.textContent = show ? "Collapse" : "Expand"
  }
}
