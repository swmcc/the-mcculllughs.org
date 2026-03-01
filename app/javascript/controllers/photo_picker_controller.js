import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal",
    "searchInput",
    "slideshowList",
    "filmstrip",
    "zoomPreview",
    "selectedCount",
    "createForm",
    "createTitleInput",
    "createDescriptionInput"
  ]
  static values = {
    images: Array
  }

  connect() {
    this.selectedIds = new Set()
    this.searchTimeout = null
    this.longPressTimeout = null
    this.isLongPress = false
    this.showingCreateForm = false
  }

  disconnect() {
    if (this.searchTimeout) clearTimeout(this.searchTimeout)
    if (this.longPressTimeout) clearTimeout(this.longPressTimeout)
  }

  open(event) {
    if (event) event.preventDefault()

    if (this.imagesValue.length === 0) {
      alert("No photos in this gallery")
      return
    }

    this.selectedIds.clear()
    this.renderFilmstrip()
    this.updateSelectedCount()
    this.searchSlideshows("")
    this.modalTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden"
    this.searchInputTarget.focus()
  }

  close(event) {
    if (event) event.preventDefault()
    this.modalTarget.classList.add("hidden")
    document.body.style.overflow = ""
    this.hideZoom()
  }

  renderFilmstrip() {
    const html = this.imagesValue.map((img, index) => `
      <div class="filmstrip-item relative flex-shrink-0 cursor-pointer transition-transform duration-150"
           data-index="${index}"
           data-id="${img.id}"
           data-action="click->photo-picker#toggleSelect mouseenter->photo-picker#showZoom mouseleave->photo-picker#hideZoom touchstart->photo-picker#touchStart touchend->photo-picker#touchEnd touchmove->photo-picker#touchMove">
        <img src="${img.thumb_webp || img.thumb}"
             alt="${img.title || ''}"
             class="h-20 w-20 object-cover rounded-lg border-2 border-transparent transition-all duration-150"
             data-full="${img.large_webp || img.large || img.medium}"
             draggable="false">
        <div class="check-overlay absolute inset-0 bg-blue-500/30 rounded-lg opacity-0 transition-opacity flex items-center justify-center">
          <svg class="w-8 h-8 text-white drop-shadow-lg" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
          </svg>
        </div>
      </div>
    `).join("")

    this.filmstripTarget.innerHTML = html
  }

  toggleSelect(event) {
    // Don't toggle if this was a long press (preview)
    if (this.isLongPress) {
      this.isLongPress = false
      return
    }

    const item = event.currentTarget
    const id = parseInt(item.dataset.id)
    const img = item.querySelector("img")
    const overlay = item.querySelector(".check-overlay")

    if (this.selectedIds.has(id)) {
      this.selectedIds.delete(id)
      img.classList.remove("border-blue-500", "scale-95")
      img.classList.add("border-transparent")
      overlay.classList.add("opacity-0")
    } else {
      this.selectedIds.add(id)
      img.classList.add("border-blue-500", "scale-95")
      img.classList.remove("border-transparent")
      overlay.classList.remove("opacity-0")
    }

    this.updateSelectedCount()
  }

  updateSelectedCount() {
    const count = this.selectedIds.size
    this.selectedCountTarget.textContent = count === 0
      ? "Tap photos to select"
      : `${count} photo${count === 1 ? "" : "s"} selected`
  }

  // Desktop: hover to zoom
  showZoom(event) {
    if ("ontouchstart" in window) return // Skip on touch devices

    const item = event.currentTarget
    const img = item.querySelector("img")
    const fullSrc = img.dataset.full

    this.zoomPreviewTarget.innerHTML = `
      <img src="${fullSrc}" class="max-h-48 max-w-xs rounded-lg shadow-2xl object-contain">
    `
    this.zoomPreviewTarget.classList.remove("hidden", "opacity-0")
    this.zoomPreviewTarget.classList.add("opacity-100")
  }

  hideZoom() {
    this.zoomPreviewTarget.classList.add("opacity-0")
    setTimeout(() => {
      if (this.zoomPreviewTarget.classList.contains("opacity-0")) {
        this.zoomPreviewTarget.classList.add("hidden")
      }
    }, 150)
  }

  // Mobile: long press to zoom
  touchStart(event) {
    this.touchStartX = event.touches[0].clientX
    this.touchStartY = event.touches[0].clientY

    this.longPressTimeout = setTimeout(() => {
      this.isLongPress = true
      const item = event.currentTarget
      const img = item.querySelector("img")
      const fullSrc = img.dataset.full

      this.zoomPreviewTarget.innerHTML = `
        <img src="${fullSrc}" class="max-h-64 max-w-sm rounded-lg shadow-2xl object-contain">
      `
      this.zoomPreviewTarget.classList.remove("hidden", "opacity-0")
      this.zoomPreviewTarget.classList.add("opacity-100")

      // Vibrate if supported
      if (navigator.vibrate) navigator.vibrate(50)
    }, 500)
  }

  touchMove(event) {
    // Cancel long press if finger moves
    const dx = Math.abs(event.touches[0].clientX - this.touchStartX)
    const dy = Math.abs(event.touches[0].clientY - this.touchStartY)
    if (dx > 10 || dy > 10) {
      clearTimeout(this.longPressTimeout)
    }
  }

  touchEnd() {
    clearTimeout(this.longPressTimeout)
    this.hideZoom()
  }

  // Slideshow search
  handleSearch(event) {
    const query = event.target.value.trim()

    if (this.searchTimeout) clearTimeout(this.searchTimeout)

    this.searchTimeout = setTimeout(() => {
      this.searchSlideshows(query)
    }, 300)
  }

  async searchSlideshows(query) {
    try {
      const url = `/slideshows/search?q=${encodeURIComponent(query)}`
      const response = await fetch(url, {
        headers: { "Accept": "application/json" }
      })

      if (!response.ok) throw new Error("Search failed")

      const slideshows = await response.json()
      this.renderSlideshowList(slideshows)
    } catch (error) {
      console.error("Search error:", error)
      this.slideshowListTarget.innerHTML = `
        <p class="text-red-500 text-sm p-4">Failed to load slideshows</p>
      `
    }
  }

  renderSlideshowList(slideshows) {
    // Create new card always appears first
    const createCard = `
      <div class="flex-shrink-0 w-48" data-photo-picker-target="createForm">
        <button type="button"
                class="create-new-card w-full bg-gradient-to-br from-blue-600 to-blue-700 hover:from-blue-500 hover:to-blue-600 rounded-xl overflow-hidden transition-all duration-200 hover:scale-105 text-left"
                data-action="click->photo-picker#showCreateForm">
          <div class="aspect-video flex items-center justify-center">
            <div class="text-center">
              <svg class="w-10 h-10 text-white/80 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
              </svg>
              <span class="text-white/90 text-sm font-medium">Create New</span>
            </div>
          </div>
          <div class="p-3">
            <p class="font-medium text-white/80 text-sm">New Slideshow</p>
            <p class="text-xs text-white/50">Add selected photos</p>
          </div>
        </button>
      </div>
    `

    if (slideshows.length === 0) {
      this.slideshowListTarget.innerHTML = createCard + `
        <div class="flex-shrink-0 flex items-center justify-center w-48 h-full text-white/40 text-center text-sm px-4">
          <span>No existing slideshows yet</span>
        </div>
      `
      return
    }

    const slideshowCards = slideshows.map(s => `
      <button type="button"
              class="slideshow-card flex-shrink-0 w-48 bg-white/10 hover:bg-white/20 rounded-xl overflow-hidden transition-all duration-200 hover:scale-105 text-left"
              data-action="click->photo-picker#addToSlideshow"
              data-slideshow-id="${s.id}"
              data-slideshow-title="${s.title}">
        <div class="aspect-video bg-neutral-800 relative">
          ${s.cover_url
            ? `<img src="${s.cover_url}" class="w-full h-full object-cover">`
            : `<div class="w-full h-full flex items-center justify-center">
                 <svg class="w-12 h-12 text-white/20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                   <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                 </svg>
               </div>`
          }
          <div class="absolute bottom-2 right-2 bg-blue-600 rounded-full p-1.5 shadow-lg">
            <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
            </svg>
          </div>
        </div>
        <div class="p-3">
          <p class="font-medium text-white truncate text-sm">${s.title}</p>
          <p class="text-xs text-white/50">${s.photo_count} photo${s.photo_count === 1 ? "" : "s"}</p>
        </div>
      </button>
    `).join("")

    this.slideshowListTarget.innerHTML = createCard + slideshowCards
  }

  showCreateForm(event) {
    event.preventDefault()
    event.stopPropagation()

    if (this.selectedIds.size === 0) {
      alert("Please select at least one photo first")
      return
    }

    // Show centered modal overlay
    this.createFormTarget.innerHTML = `
      <div class="fixed inset-0 z-[60] flex items-center justify-center bg-black/60 backdrop-blur-sm"
           data-action="click->photo-picker#cancelCreate">
        <div class="bg-white rounded-2xl overflow-hidden shadow-2xl w-full max-w-md mx-4"
             data-action="click->photo-picker#stopPropagation">
          <div class="bg-gradient-to-r from-blue-600 to-blue-700 px-6 py-4">
            <h3 class="text-white font-semibold text-lg">Create New Slideshow</h3>
            <p class="text-white/70 text-sm">${this.selectedIds.size} photo${this.selectedIds.size === 1 ? '' : 's'} selected</p>
          </div>
          <div class="p-6 space-y-4">
            <div>
              <label class="block text-sm font-medium text-neutral-700 mb-2">Title *</label>
              <input type="text"
                     data-photo-picker-target="createTitleInput"
                     placeholder="Enter slideshow title..."
                     class="w-full px-4 py-3 text-base border border-neutral-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                     required>
            </div>
            <div>
              <label class="block text-sm font-medium text-neutral-700 mb-2">Description *</label>
              <textarea data-photo-picker-target="createDescriptionInput"
                        placeholder="Add a short description..."
                        rows="3"
                        class="w-full px-4 py-3 text-base border border-neutral-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
                        required></textarea>
            </div>
            <div class="flex gap-3 pt-2">
              <button type="button"
                      data-action="click->photo-picker#cancelCreate"
                      class="flex-1 px-4 py-3 text-base font-medium text-neutral-700 bg-neutral-100 hover:bg-neutral-200 rounded-xl transition-colors">
                Cancel
              </button>
              <button type="button"
                      data-action="click->photo-picker#createSlideshow"
                      class="flex-1 px-4 py-3 text-base font-medium text-white bg-blue-600 hover:bg-blue-700 rounded-xl transition-colors">
                Create Slideshow
              </button>
            </div>
          </div>
        </div>
      </div>
    `

    this.showingCreateForm = true
    // Focus the title input
    setTimeout(() => {
      if (this.hasCreateTitleInputTarget) {
        this.createTitleInputTarget.focus()
      }
    }, 100)
  }

  cancelCreate(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }
    this.showingCreateForm = false
    // Clear the modal and restore the create card
    if (this.hasCreateFormTarget) {
      this.createFormTarget.innerHTML = `
        <button type="button"
                class="create-new-card w-full bg-gradient-to-br from-blue-600 to-blue-700 hover:from-blue-500 hover:to-blue-600 rounded-xl overflow-hidden transition-all duration-200 hover:scale-105 text-left"
                data-action="click->photo-picker#showCreateForm">
          <div class="aspect-video flex items-center justify-center">
            <div class="text-center">
              <svg class="w-10 h-10 text-white/80 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
              </svg>
              <span class="text-white/90 text-sm font-medium">Create New</span>
            </div>
          </div>
          <div class="p-3">
            <p class="font-medium text-white/80 text-sm">New Slideshow</p>
            <p class="text-xs text-white/50">Add selected photos</p>
          </div>
        </button>
      `
    }
  }

  async createSlideshow(event) {
    event.preventDefault()
    event.stopPropagation()

    const title = this.createTitleInputTarget.value.trim()
    const description = this.createDescriptionInputTarget.value.trim()

    if (!title) {
      this.createTitleInputTarget.focus()
      this.createTitleInputTarget.classList.add("border-red-500")
      return
    }

    if (!description) {
      this.createDescriptionInputTarget.focus()
      this.createDescriptionInputTarget.classList.add("border-red-500")
      return
    }

    const formData = new FormData()
    formData.append('slideshow[title]', title)
    formData.append('slideshow[description]', description)
    formData.append('slideshow[interval]', 5)

    // Add selected upload IDs
    this.selectedIds.forEach(id => {
      formData.append('upload_ids[]', id)
    })

    try {
      const response = await fetch('/slideshows', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: formData
      })

      const result = await response.json()

      if (response.ok) {
        this.showToast(`Created "${title}" with ${this.selectedIds.size} photos`, "success")

        // Clear selection
        this.selectedIds.clear()
        this.renderFilmstrip()
        this.updateSelectedCount()

        // Close modal and refresh slideshow list to show the new one
        this.showingCreateForm = false
        this.cancelCreate() // Restore the create card
        this.searchSlideshows(this.searchInputTarget.value.trim())
      } else {
        this.showToast(result.errors ? result.errors.join(", ") : "Failed to create slideshow", "error")
      }
    } catch (error) {
      console.error("Create error:", error)
      this.showToast("Failed to create slideshow", "error")
    }
  }

  async addToSlideshow(event) {
    event.preventDefault()

    if (this.selectedIds.size === 0) {
      alert("Please select at least one photo first")
      return
    }

    const button = event.currentTarget
    const slideshowId = button.dataset.slideshowId
    const slideshowTitle = button.dataset.slideshowTitle

    // Disable button while processing
    button.disabled = true
    button.classList.add("opacity-50")

    try {
      const response = await fetch(`/slideshows/${slideshowId}/add_uploads`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          upload_ids: Array.from(this.selectedIds)
        })
      })

      const result = await response.json()

      if (response.ok) {
        // Show success feedback
        const count = result.added_count
        const message = count === 0
          ? "Photos already in slideshow"
          : `Added ${count} photo${count === 1 ? "" : "s"} to "${slideshowTitle}"`

        this.showToast(message, count > 0 ? "success" : "info")

        // Clear selection after successful add
        this.selectedIds.clear()
        this.renderFilmstrip()
        this.updateSelectedCount()
      } else {
        this.showToast(result.error || "Failed to add photos", "error")
      }
    } catch (error) {
      console.error("Add error:", error)
      this.showToast("Failed to add photos", "error")
    } finally {
      button.disabled = false
      button.classList.remove("opacity-50")
    }
  }

  showToast(message, type = "success") {
    const colors = {
      success: "bg-green-600",
      error: "bg-red-600",
      info: "bg-blue-600"
    }

    const toast = document.createElement("div")
    toast.className = `fixed bottom-24 left-1/2 -translate-x-1/2 px-4 py-2 rounded-lg text-white text-sm font-medium shadow-lg z-[60] ${colors[type]}`
    toast.textContent = message
    document.body.appendChild(toast)

    setTimeout(() => {
      toast.classList.add("opacity-0", "transition-opacity")
      setTimeout(() => toast.remove(), 300)
    }, 2500)
  }

  // Keyboard handling
  keydown(event) {
    if (this.modalTarget.classList.contains("hidden")) return

    if (event.key === "Escape") {
      this.close()
    }
  }

  stopPropagation(event) {
    event.stopPropagation()
  }
}
