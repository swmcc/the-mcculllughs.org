import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "image", "title", "caption", "counter", "downloadMenu", "prevBtn", "nextBtn"]
  static values = {
    images: Array,
    index: { type: Number, default: 0 }
  }

  connect() {
    // Add error handler for image loading
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

    // Try large first, fallback to original
    this.imageTarget.src = image.large || image.original

    // Update title and caption
    if (this.hasTitleTarget) {
      this.titleTarget.textContent = image.title || ""
      this.titleTarget.classList.toggle("hidden", !image.title)
    }

    if (this.hasCaptionTarget) {
      this.captionTarget.textContent = image.caption || ""
      this.captionTarget.classList.toggle("hidden", !image.caption)
    }

    // Update counter
    this.counterTarget.textContent = `${this.indexValue + 1} / ${this.imagesValue.length}`

    // Update download links
    this.updateDownloadLinks(image)

    // Update prev/next button visibility
    this.prevBtnTarget.classList.toggle("invisible", this.indexValue === 0)
    this.nextBtnTarget.classList.toggle("invisible", this.indexValue === this.imagesValue.length - 1)

    // Show modal
    this.modalTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
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
