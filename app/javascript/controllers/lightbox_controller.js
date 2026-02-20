import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "image", "caption", "counter"]
  static values = {
    images: Array,
    index: { type: Number, default: 0 }
  }

  open(event) {
    event.preventDefault()
    const index = parseInt(event.currentTarget.dataset.index)
    this.indexValue = index
    this.show()
  }

  show() {
    const image = this.imagesValue[this.indexValue]
    this.imageTarget.src = image.url
    this.imageTarget.alt = image.title || ""
    this.captionTarget.textContent = image.title || ""
    this.counterTarget.textContent = `${this.indexValue + 1} / ${this.imagesValue.length}`
    this.modalTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
  }

  close(event) {
    if (event) event.stopPropagation()
    this.modalTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  prev(event) {
    event.stopPropagation()
    if (this.indexValue > 0) {
      this.indexValue--
      this.show()
    }
  }

  next(event) {
    event.stopPropagation()
    if (this.indexValue < this.imagesValue.length - 1) {
      this.indexValue++
      this.show()
    }
  }

  keydown(event) {
    if (this.modalTarget.classList.contains("hidden")) return

    switch (event.key) {
      case "Escape":
        this.modalTarget.classList.add("hidden")
        document.body.classList.remove("overflow-hidden")
        break
      case "ArrowLeft":
        this.prev(event)
        break
      case "ArrowRight":
        this.next(event)
        break
    }
  }

  get hasPrev() {
    return this.indexValue > 0
  }

  get hasNext() {
    return this.indexValue < this.imagesValue.length - 1
  }
}
