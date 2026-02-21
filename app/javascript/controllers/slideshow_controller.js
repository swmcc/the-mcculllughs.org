import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "configModal", "image", "counter", "intervalInput"]
  static values = {
    images: Array,
    interval: { type: Number, default: 5 }
  }

  // Available transitions
  transitions = ["fade", "slide-left", "slide-right", "zoom"]

  connect() {
    this.currentIndex = 0
    this.timer = null
    this.lastTransition = null
  }

  disconnect() {
    this.stop()
  }

  // Open config modal to set interval
  openConfig(event) {
    event.preventDefault()
    if (this.imagesValue.length === 0) {
      alert("No photos in this gallery")
      return
    }
    this.configModalTarget.classList.remove("hidden")
    this.intervalInputTarget.focus()
  }

  closeConfig(event) {
    if (event) event.preventDefault()
    this.configModalTarget.classList.add("hidden")
  }

  // Start slideshow with configured interval
  start(event) {
    event.preventDefault()
    const interval = parseInt(this.intervalInputTarget.value, 10) || 5
    this.intervalValue = interval
    this.currentIndex = 0

    this.closeConfig()
    this.showSlideshow()
    this.showImage(false) // No transition for first image
    this.startTimer()
  }

  showSlideshow() {
    this.modalTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden"
  }

  close(event) {
    if (event) event.preventDefault()
    this.stop()
    this.modalTarget.classList.add("hidden")
    document.body.style.overflow = ""
  }

  showImage(withTransition = true) {
    const img = this.imagesValue[this.currentIndex]
    if (!img) return

    if (withTransition) {
      this.applyTransition(() => {
        this.imageTarget.src = img.large || img.medium || img.original
      })
    } else {
      this.imageTarget.src = img.large || img.medium || img.original
    }
    this.counterTarget.textContent = `${this.currentIndex + 1} / ${this.imagesValue.length}`
  }

  pickRandomTransition() {
    // Pick a random transition, avoiding the same one twice in a row
    let available = this.transitions.filter(t => t !== this.lastTransition)
    const transition = available[Math.floor(Math.random() * available.length)]
    this.lastTransition = transition
    return transition
  }

  applyTransition(loadNewImage) {
    const transition = this.pickRandomTransition()
    const img = this.imageTarget

    // Remove any existing transition classes
    img.classList.remove("fade-in", "fade-out", "slide-in-left", "slide-out-left",
                         "slide-in-right", "slide-out-right", "zoom-in", "zoom-out")

    // Apply exit animation
    switch (transition) {
      case "fade":
        img.classList.add("fade-out")
        break
      case "slide-left":
        img.classList.add("slide-out-left")
        break
      case "slide-right":
        img.classList.add("slide-out-right")
        break
      case "zoom":
        img.classList.add("zoom-out")
        break
    }

    // After exit animation, load new image and apply enter animation
    setTimeout(() => {
      loadNewImage()
      img.classList.remove("fade-out", "slide-out-left", "slide-out-right", "zoom-out")

      switch (transition) {
        case "fade":
          img.classList.add("fade-in")
          break
        case "slide-left":
          img.classList.add("slide-in-left")
          break
        case "slide-right":
          img.classList.add("slide-in-right")
          break
        case "zoom":
          img.classList.add("zoom-in")
          break
      }

      // Clean up after animation completes
      setTimeout(() => {
        img.classList.remove("fade-in", "slide-in-left", "slide-in-right", "zoom-in")
      }, 500)
    }, 300)
  }

  next() {
    this.currentIndex = (this.currentIndex + 1) % this.imagesValue.length
    this.showImage()
  }

  prev() {
    this.currentIndex = (this.currentIndex - 1 + this.imagesValue.length) % this.imagesValue.length
    this.showImage()
  }

  startTimer() {
    this.stopTimer()
    this.timer = setInterval(() => this.next(), this.intervalValue * 1000)
  }

  stopTimer() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }

  stop() {
    this.stopTimer()
  }

  // Pause on manual navigation, then resume
  manualPrev(event) {
    event.preventDefault()
    event.stopPropagation()
    this.prev()
    this.startTimer() // Reset timer
  }

  manualNext(event) {
    event.preventDefault()
    event.stopPropagation()
    this.next()
    this.startTimer() // Reset timer
  }

  togglePause(event) {
    event.preventDefault()
    event.stopPropagation()
    if (this.timer) {
      this.stopTimer()
      event.currentTarget.innerHTML = this.playIcon()
    } else {
      this.startTimer()
      event.currentTarget.innerHTML = this.pauseIcon()
    }
  }

  playIcon() {
    return `<svg class="w-8 h-8" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>`
  }

  pauseIcon() {
    return `<svg class="w-8 h-8" fill="currentColor" viewBox="0 0 24 24"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>`
  }

  keydown(event) {
    // Config modal open
    if (!this.configModalTarget.classList.contains("hidden")) {
      if (event.key === "Escape") this.closeConfig()
      if (event.key === "Enter") this.start(event)
      return
    }

    // Slideshow open
    if (!this.modalTarget.classList.contains("hidden")) {
      switch (event.key) {
        case "Escape":
          this.close()
          break
        case "ArrowLeft":
          this.prev()
          this.startTimer()
          break
        case "ArrowRight":
          this.next()
          this.startTimer()
          break
        case " ":
          event.preventDefault()
          this.togglePause(event)
          break
      }
    }
  }

  stopPropagation(event) {
    event.stopPropagation()
  }
}
