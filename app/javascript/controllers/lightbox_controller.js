import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "image", "title", "caption", "dateTaken", "counter", "downloadMenu", "prevBtn", "nextBtn", "titleInput", "captionInput", "dateTakenInput", "saveStatus", "noInfo", "publicToggle", "publicLabel", "copyLinkBtn", "copyLinkText"]
  static values = {
    images: Array,
    index: { type: Number, default: 0 },
    canEdit: { type: Boolean, default: false }
  }

  connect() {
    this.saveTimeout = null
    this.imageTarget.onerror = () => {
      const image = this.imagesValue[this.indexValue]
      // Fallback to original if variant fails
      if (this.imageTarget.src !== image.original) {
        this.imageTarget.src = image.original
      }
    }
  }

  open(event) {
    event.preventDefault()
    const index = parseInt(event.currentTarget.dataset.index)
    this.indexValue = index
    this.show()
  }

  show() {
    const image = this.imagesValue[this.indexValue]
    // Use large variant (WebP), fallback to original
    this.imageTarget.src = image.large || image.original

    // Update editable inputs
    if (this.canEditValue && this.hasTitleInputTarget) {
      this.titleInputTarget.value = image.title || ""
    }
    if (this.canEditValue && this.hasCaptionInputTarget) {
      this.captionInputTarget.value = image.caption || ""
    }
    if (this.canEditValue && this.hasDateTakenInputTarget) {
      this.dateTakenInputTarget.value = image.date_taken || ""
    }
    if (this.hasSaveStatusTarget) {
      this.saveStatusTarget.textContent = ""
    }

    // Update read-only date display
    if (this.hasDateTakenTarget) {
      if (image.date_taken) {
        const date = new Date(image.date_taken)
        this.dateTakenTarget.textContent = date.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })
        this.dateTakenTarget.classList.remove("hidden")
      } else {
        this.dateTakenTarget.textContent = ""
        this.dateTakenTarget.classList.add("hidden")
      }
    }

    // Update public toggle
    if (this.hasPublicToggleTarget) {
      this.publicToggleTarget.checked = image.is_public || false
      this.updatePublicUI(image.is_public)
    }

    // Update read-only display
    const hasTitle = image.title && image.title.trim()
    const hasCaption = image.caption && image.caption.trim()
    const hasAnyInfo = hasTitle || hasCaption

    if (this.hasTitleTarget) {
      this.titleTarget.textContent = image.title || ""
      this.titleTarget.classList.toggle("hidden", !hasTitle)
    }
    if (this.hasCaptionTarget) {
      this.captionTarget.textContent = image.caption || ""
      this.captionTarget.classList.toggle("hidden", !hasCaption)
    }
    if (this.hasNoInfoTarget) {
      this.noInfoTarget.classList.toggle("hidden", hasAnyInfo)
    }

    this.counterTarget.textContent = `${this.indexValue + 1} / ${this.imagesValue.length}`
    this.updateDownloadLinks(image)

    this.prevBtnTarget.classList.toggle("invisible", this.indexValue === 0)
    this.nextBtnTarget.classList.toggle("invisible", this.indexValue === this.imagesValue.length - 1)

    this.modalTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
  }

  handleInput(event) {
    if (!this.canEditValue) return

    if (this.hasSaveStatusTarget) {
      this.saveStatusTarget.textContent = ""
    }

    clearTimeout(this.saveTimeout)
    this.saveTimeout = setTimeout(() => this.save(), 400)
  }

  async save() {
    const image = this.imagesValue[this.indexValue]
    const title = this.hasTitleInputTarget ? this.titleInputTarget.value : image.title
    const caption = this.hasCaptionInputTarget ? this.captionInputTarget.value : image.caption
    const date_taken = this.hasDateTakenInputTarget ? this.dateTakenInputTarget.value : image.date_taken

    if (this.hasSaveStatusTarget) {
      this.saveStatusTarget.textContent = "Saving..."
      this.saveStatusTarget.className = "text-white/50 text-xs"
    }

    try {
      const response = await fetch(`/uploads/${image.id}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: JSON.stringify({ upload: { title, caption, date_taken } })
      })

      if (response.ok) {
        // Update local data (create new array to ensure Stimulus detects change)
        const images = [...this.imagesValue]
        images[this.indexValue] = { ...images[this.indexValue], title, caption, date_taken }
        this.imagesValue = images

        // Update all UI elements for this upload
        this.updateUploadUI(image.id, title, caption)

        if (this.hasSaveStatusTarget) {
          this.saveStatusTarget.textContent = "Saved"
          this.saveStatusTarget.className = "text-green-400 text-xs"
          setTimeout(() => {
            if (this.hasSaveStatusTarget) this.saveStatusTarget.textContent = ""
          }, 2000)
        }
      } else {
        throw new Error("Save failed")
      }
    } catch (error) {
      if (this.hasSaveStatusTarget) {
        this.saveStatusTarget.textContent = "Failed to save"
        this.saveStatusTarget.className = "text-red-400 text-xs"
      }
    }
  }

  updateUploadUI(uploadId, title, caption) {
    // Update thumbnail title overlay
    const titleEl = document.querySelector(`[data-upload-title="${uploadId}"]`)
    if (titleEl) {
      titleEl.textContent = title || ""
      titleEl.classList.toggle("hidden", !title)
    }

    // Update thumbnail image alt text
    const imgEl = document.querySelector(`[data-upload-image="${uploadId}"]`)
    if (imgEl) {
      imgEl.alt = title || ""
    }
  }

  updateDownloadLinks(image) {
    const menu = this.downloadMenuTarget
    menu.innerHTML = ""

    const sizes = [
      { name: "Original", url: image.original },
      { name: "Large", url: image.large, desc: "2048px" },
      { name: "Medium", url: image.medium, desc: "1024px" },
      { name: "Thumbnail", url: image.thumb, desc: "400px" }
    ].filter(s => s.url)

    sizes.forEach(size => {
      const link = document.createElement("a")
      link.href = size.url
      link.download = ""
      link.target = "_blank"
      link.className = "flex items-center justify-between px-4 py-2 text-sm text-white/90 hover:bg-white/10 transition-colors"
      link.innerHTML = `
        <span>${size.name}</span>
        ${size.desc ? `<span class="text-white/50 text-xs">${size.desc}</span>` : ""}
      `
      link.addEventListener("click", (e) => e.stopPropagation())
      menu.appendChild(link)
    })
  }

  toggleDownload(event) {
    event.stopPropagation()
    this.downloadMenuTarget.classList.toggle("hidden")
  }

  close(event) {
    if (event) event.stopPropagation()
    this.modalTarget.classList.add("hidden")
    this.downloadMenuTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  prev(event) {
    event.stopPropagation()
    this.downloadMenuTarget.classList.add("hidden")
    if (this.indexValue > 0) {
      this.indexValue--
      this.show()
    }
  }

  next(event) {
    event.stopPropagation()
    this.downloadMenuTarget.classList.add("hidden")
    if (this.indexValue < this.imagesValue.length - 1) {
      this.indexValue++
      this.show()
    }
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  updatePublicUI(isPublic) {
    if (this.hasPublicLabelTarget) {
      this.publicLabelTarget.textContent = isPublic ? "Public" : "Private"
    }
    if (this.hasCopyLinkBtnTarget) {
      this.copyLinkBtnTarget.classList.toggle("hidden", !isPublic)
      this.copyLinkBtnTarget.classList.toggle("flex", isPublic)
    }
  }

  async handlePublicToggle(event) {
    if (!this.canEditValue) return

    const isPublic = event.target.checked
    const image = this.imagesValue[this.indexValue]

    this.updatePublicUI(isPublic)

    if (this.hasSaveStatusTarget) {
      this.saveStatusTarget.textContent = "Saving..."
      this.saveStatusTarget.className = "text-white/50 text-xs"
    }

    try {
      const response = await fetch(`/uploads/${image.id}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: JSON.stringify({ upload: { is_public: isPublic } })
      })

      if (response.ok) {
        const data = await response.json()
        // Update local data
        const images = [...this.imagesValue]
        images[this.indexValue] = {
          ...images[this.indexValue],
          is_public: isPublic,
          short_code: data.short_code
        }
        this.imagesValue = images

        if (this.hasSaveStatusTarget) {
          this.saveStatusTarget.textContent = "Saved"
          this.saveStatusTarget.className = "text-green-400 text-xs"
          setTimeout(() => {
            if (this.hasSaveStatusTarget) this.saveStatusTarget.textContent = ""
          }, 2000)
        }
      } else {
        throw new Error("Save failed")
      }
    } catch (error) {
      // Revert toggle on error
      event.target.checked = !isPublic
      this.updatePublicUI(!isPublic)

      if (this.hasSaveStatusTarget) {
        this.saveStatusTarget.textContent = "Failed to save"
        this.saveStatusTarget.className = "text-red-400 text-xs"
      }
    }
  }

  async copyLink(event) {
    event.stopPropagation()
    const image = this.imagesValue[this.indexValue]

    if (!image.short_code) return

    const url = `${window.location.origin}/p/${image.short_code}`

    try {
      await navigator.clipboard.writeText(url)
      if (this.hasCopyLinkTextTarget) {
        this.copyLinkTextTarget.textContent = "Copied!"
        setTimeout(() => {
          if (this.hasCopyLinkTextTarget) this.copyLinkTextTarget.textContent = "Copy link"
        }, 2000)
      }
    } catch (error) {
      // Fallback for older browsers
      const textArea = document.createElement("textarea")
      textArea.value = url
      document.body.appendChild(textArea)
      textArea.select()
      document.execCommand("copy")
      document.body.removeChild(textArea)

      if (this.hasCopyLinkTextTarget) {
        this.copyLinkTextTarget.textContent = "Copied!"
        setTimeout(() => {
          if (this.hasCopyLinkTextTarget) this.copyLinkTextTarget.textContent = "Copy link"
        }, 2000)
      }
    }
  }

  keydown(event) {
    if (this.modalTarget.classList.contains("hidden")) return

    if (event.target.tagName === "INPUT" || event.target.tagName === "TEXTAREA") {
      if (event.key === "Escape") {
        event.target.blur()
      }
      return
    }

    switch (event.key) {
      case "Escape":
        this.close()
        break
      case "ArrowLeft":
        this.prev(event)
        break
      case "ArrowRight":
        this.next(event)
        break
    }
  }
}
