import { Controller } from "@hotwired/stimulus"

// Shows or hides a page's search form, and remembers the choice in a cookie so the
// server renders it the same way next time.
export default class extends Controller {
  static targets = [ "form", "icon" ]
  static values = { cookie: String }

  toggle() {
    const show = this.formTarget.style.display === "none"
    this.formTarget.style.display = show ? "block" : "none"
    this.iconTarget.classList.toggle("glyphicon-chevron-up", show)
    this.iconTarget.classList.toggle("glyphicon-chevron-down", !show)

    const path = window.location.pathname
    document.cookie = show
      ? `${this.cookieValue}=true; path=${path}; SameSite=Lax`
      : `${this.cookieValue}=; path=${path}; max-age=0; SameSite=Lax`
  }
}
