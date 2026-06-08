import { Controller } from "@hotwired/stimulus"

// Disables the submit button and shows a spinner while a link form is being submitted.
// Wires into Turbo's submit lifecycle so it works for create, edit, and Turbo Drive navigations.
export default class extends Controller {
  static targets = ["submit"]

  connect() {
    this.handleSubmitStart = this.handleSubmitStart.bind(this)
    this.handleSubmitEnd = this.handleSubmitEnd.bind(this)
    this.element.addEventListener("turbo:submit-start", this.handleSubmitStart)
    this.element.addEventListener("turbo:submit-end", this.handleSubmitEnd)
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-start", this.handleSubmitStart)
    this.element.removeEventListener("turbo:submit-end", this.handleSubmitEnd)
  }

  handleSubmitStart() {
    if (!this.hasSubmitTarget) return
    this.originalLabel = this.submitTarget.innerHTML
    this.submitTarget.disabled = true
    this.submitTarget.innerHTML = this.#spinnerMarkup() + "Saving…"
    this.submitTarget.classList.add("opacity-75", "cursor-wait")
  }

  handleSubmitEnd(event) {
    if (!this.hasSubmitTarget) return
    if (event.detail.success) return  // navigation will replace this DOM anyway
    this.submitTarget.disabled = false
    this.submitTarget.innerHTML = this.originalLabel
    this.submitTarget.classList.remove("opacity-75", "cursor-wait")
  }

  #spinnerMarkup() {
    return `
      <svg class="inline-block animate-spin -ml-1 mr-2 h-4 w-4 text-white align-middle" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4l3-3-3-3v4a8 8 0 100 16v-4l-3 3 3 3v-4a8 8 0 01-8-8z"></path>
      </svg>
    `
  }
}
