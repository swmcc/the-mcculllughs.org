import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "image", "title", "caption", "counter", "downloadMenu", "prevBtn", "nextBtn", "titleInput", "captionInput", "saveStatus", "noInfo"]
  static values = {
    images: Array,
    index: { type: Number, default: 0 },
    canEdit: { type: Boolean, default: false }
  }

  connect() {
    this.saveTimeout = null
    this.imageTarget.onerror = () => {
      const image = this.imagesValue[this.indexValue]
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
    this.imageTarget.src = image.large || image.original

    // Update editable inputs
    if (this.canEditValue && this.hasTitleInputTarget) {
      this.titleInputTarget.value = image.title || ""
    }
    if (this.canEditValue && this.hasCaptionInputTarget) {
      this.captionInputTarget.value = image.caption || ""
    }
    if (this.hasSaveStatusTarget) {
      this.saveStatusTarget.textContent = ""
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
        body: JSON.stringify({ upload: { title, caption } })
      })

      if (response.ok) {
        // Update local data
        this.imagesValue[this.indexValue].title = title
        this.imagesValue[this.indexValue].caption = caption

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
      { name: "Small", url: image.small, desc: "640px" }
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
