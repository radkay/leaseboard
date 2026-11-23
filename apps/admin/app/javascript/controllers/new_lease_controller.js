import { Controller } from "@hotwired/stimulus"

// A non-blocking floating panel for signing a new lease: a native <dialog> opened
// with show() (not showModal, so it doesn't block the page). It closes itself when
// the Turbo form submission succeeds; on a validation error the stream re-renders
// the form inside the panel and it stays open.
export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.show()
  }

  close() {
    this.dialogTarget.close()
  }

  submitEnd(event) {
    if (event.detail.success) this.dialogTarget.close()
  }
}
