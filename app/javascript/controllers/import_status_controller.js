import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    id: Number,
    url: String,
    complete: Boolean,
    refreshInterval: { type: Number, default: 2000 }
  }

  connect() {
    if (!this.completeValue) {
      this.startPolling()
    }
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    this.pollTimer = setInterval(() => this.refresh(), this.refreshIntervalValue)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
    }
  }

  async refresh() {
    try {
      const response = await fetch(this.urlValue, {
        headers: {
          Accept: "text/vnd.turbo-stream.html",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']")?.content
        }
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)

        // Check if import is complete by looking for completion indicators
        if (html.includes("View Gallery") || html.includes("bg-red-50")) {
          this.stopPolling()
        }
      }
    } catch (error) {
      console.error("Failed to refresh import status:", error)
    }
  }
}
