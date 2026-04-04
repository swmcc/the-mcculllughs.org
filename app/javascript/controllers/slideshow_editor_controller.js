import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["photoGrid", "photoCount", "emptyState"]
  static values = {
    slideshowId: Number,
    addUrl: String,
    removeUrl: String,
    reorderUrl: String
  }

  connect() {
    this.selectedPhotos = new Set()
  }

  async removePhoto(event) {
    const button = event.currentTarget
    const uploadId = button.dataset.uploadId

    if (!confirm("Remove this photo from the slideshow?")) {
      return
    }

    try {
      const response = await fetch(`${this.removeUrlValue}?upload_id=${uploadId}`, {
        method: "DELETE",
        headers: {
          "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content,
          "Accept": "application/json"
        }
      })

      if (response.ok) {
        const data = await response.json()

        // Remove the photo from the grid
        const photoElement = button.closest("[data-upload-id]")
        photoElement.remove()

        // Update the count
        this.updatePhotoCount(data.total_count)

        // Update the "Added" badge in gallery picker
        this.updateGalleryPickerState(uploadId, false)

        // Show empty state if no photos left
        if (data.total_count === 0 && this.hasEmptyStateTarget) {
          this.photoGridTarget.innerHTML = ""
          this.emptyStateTarget.classList.remove("hidden")
        }
      } else {
        alert("Failed to remove photo. Please try again.")
      }
    } catch (error) {
      console.error("Error removing photo:", error)
      alert("Failed to remove photo. Please try again.")
    }
  }

  async togglePhoto(event) {
    const checkbox = event.currentTarget
    const uploadId = checkbox.dataset.uploadId
    const isChecked = checkbox.checked

    if (isChecked) {
      await this.addPhoto(uploadId, checkbox)
    }
  }

  async addPhoto(uploadId, checkbox) {
    try {
      const response = await fetch(this.addUrlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content,
          "Content-Type": "application/json",
          "Accept": "application/json"
        },
        body: JSON.stringify({ upload_ids: [uploadId] })
      })

      if (response.ok) {
        const data = await response.json()

        // Update the count
        this.updatePhotoCount(data.total_count)

        // Reload to show the new photo in the grid
        // (A more sophisticated approach would dynamically add it)
        window.location.reload()
      } else {
        checkbox.checked = false
        alert("Failed to add photo. Please try again.")
      }
    } catch (error) {
      console.error("Error adding photo:", error)
      checkbox.checked = false
      alert("Failed to add photo. Please try again.")
    }
  }

  updatePhotoCount(count) {
    if (this.hasPhotoCountTarget) {
      this.photoCountTarget.textContent = `(${count})`
    }
  }

  updateGalleryPickerState(uploadId, isAdded) {
    // Find the checkbox in the gallery picker and update its state
    const checkbox = this.element.querySelector(`input[data-upload-id="${uploadId}"]`)
    if (checkbox) {
      checkbox.checked = isAdded
      checkbox.disabled = isAdded

      const container = checkbox.closest(".relative")
      const label = checkbox.closest("label")
      const badge = container.querySelector(".bg-green-500")

      if (isAdded) {
        label.classList.add("opacity-50")
        if (!badge) {
          const newBadge = document.createElement("div")
          newBadge.className = "absolute top-1 right-1 bg-green-500 text-white text-xs px-1.5 py-0.5 rounded"
          newBadge.textContent = "Added"
          container.appendChild(newBadge)
        }
      } else {
        label.classList.remove("opacity-50")
        if (badge) badge.remove()
      }
    }
  }
}
