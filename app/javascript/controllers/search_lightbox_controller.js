import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "image", "counter", "prevBtn", "nextBtn", "title", "caption", "dateTaken", "galleryLink", "galleryTitle"]
  static values = { images: Array }

  connect() {
    this.currentIndex = 0
  }

  open(event) {
    event.preventDefault()
    this.currentIndex = parseInt(event.currentTarget.dataset.index, 10)
    this.showImage()
    this.modalTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden"
  }

  close(event) {
    if (event) event.preventDefault()
    this.modalTarget.classList.add("hidden")
    document.body.style.overflow = ""
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  next(event) {
    if (event) event.preventDefault()
    if (this.currentIndex < this.imagesValue.length - 1) {
      this.currentIndex++
      this.showImage()
    }
  }

  prev(event) {
    if (event) event.preventDefault()
    if (this.currentIndex > 0) {
      this.currentIndex--
      this.showImage()
    }
  }

  keydown(event) {
    if (this.modalTarget.classList.contains("hidden")) return

    switch (event.key) {
      case "Escape":
        this.close()
        break
      case "ArrowLeft":
        this.prev()
        break
      case "ArrowRight":
        this.next()
        break
    }
  }

  showImage() {
    const img = this.imagesValue[this.currentIndex]
    if (!img) return

    // Update image
    this.imageTarget.src = img.original

    // Update counter
    this.counterTarget.textContent = `${this.currentIndex + 1} / ${this.imagesValue.length}`

    // Update title
    this.titleTarget.textContent = img.title || ""

    // Update caption
    this.captionTarget.textContent = img.caption || ""

    // Update date
    if (img.date_taken) {
      const date = new Date(img.date_taken)
      this.dateTakenTarget.textContent = date.toLocaleDateString("en-GB", {
        day: "numeric",
        month: "short",
        year: "numeric"
      })
    } else {
      this.dateTakenTarget.textContent = ""
    }

    // Update gallery link
    this.galleryLinkTarget.href = img.gallery_path
    this.galleryTitleTarget.textContent = img.gallery_title || "View in Gallery"

    // Update nav buttons
    this.prevBtnTarget.classList.toggle("invisible", this.currentIndex === 0)
    this.nextBtnTarget.classList.toggle("invisible", this.currentIndex === this.imagesValue.length - 1)
  }
}
