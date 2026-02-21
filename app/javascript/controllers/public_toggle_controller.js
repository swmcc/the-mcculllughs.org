import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "label", "status"]
  static values = {
    shortCode: String,
    isPublic: Boolean
  }

  async toggle(event) {
    const isPublic = event.target.checked

    this.labelTarget.textContent = isPublic ? "Public" : "Private"
    this.statusTarget.textContent = "Saving..."
    this.statusTarget.className = "text-white/50 text-xs"

    try {
      const response = await fetch(`/p/${this.shortCodeValue}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: JSON.stringify({ upload: { is_public: isPublic } })
      })

      if (response.ok) {
        this.isPublicValue = isPublic
        this.statusTarget.textContent = "Saved"
        this.statusTarget.className = "text-green-400 text-xs"
        setTimeout(() => {
          this.statusTarget.textContent = ""
        }, 2000)
      } else {
        throw new Error("Save failed")
      }
    } catch (error) {
      // Revert on error
      this.checkboxTarget.checked = !isPublic
      this.labelTarget.textContent = !isPublic ? "Public" : "Private"
      this.statusTarget.textContent = "Failed"
      this.statusTarget.className = "text-red-400 text-xs"
    }
  }
}
