import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "configModal", "image", "counter", "intervalInput", "title", "caption", "dateTaken", "pauseBtn", "titleSlide", "imageArea", "galleryTitle", "galleryDescription", "photoCount", "infoBar", "saveModal", "saveTitleInput", "saveDescriptionInput", "saveIntervalInput", "saveAudioInput", "startBtn", "audio", "audioToggle", "audioIcon"]
  static values = {
    images: Array,
    interval: { type: Number, default: 5 },
    galleryTitle: String,
    galleryDescription: String,
    audioUrl: String,
    autoplay: { type: Boolean, default: false }
  }

  // Available transitions
  transitions = ["fade", "slide-left", "slide-right", "zoom"]

  connect() {
    this.currentIndex = -1 // -1 = title slide, 0+ = photos
    this.timer = null
    this.lastTransition = null
    this.audioPlaying = false
    this.supportsWebP = this.checkWebPSupport()
  }

  checkWebPSupport() {
    const canvas = document.createElement('canvas')
    canvas.width = 1
    canvas.height = 1
    return canvas.toDataURL('image/webp').indexOf('data:image/webp') === 0
  }

  getImageSrc(img) {
    // Prefer WebP if browser supports it
    if (this.supportsWebP && img.large_webp) {
      return img.large_webp
    }
    return img.large || img.medium || img.original
  }

  // Called when user clicks "Start Slideshow" on saved slideshow title screen
  startSavedSlideshow(event) {
    if (event) event.preventDefault()

    // Hide the start button
    if (this.hasStartBtnTarget) {
      this.startBtnTarget.classList.add("hidden")
    }

    // Start audio playback (user has interacted, so autoplay works)
    this.playAudio()

    // Start the slideshow timer
    this.startTimer()
  }

  playAudio() {
    if (!this.hasAudioTarget) return

    this.audioTarget.play().then(() => {
      this.audioPlaying = true
      this.updateAudioIcon()
    }).catch(err => {
      console.log("Audio playback failed:", err)
    })
  }

  toggleAudio(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }

    if (!this.hasAudioTarget) return

    if (this.audioPlaying) {
      this.audioTarget.pause()
      this.audioPlaying = false
    } else {
      this.audioTarget.play()
      this.audioPlaying = true
    }
    this.updateAudioIcon()
  }

  updateAudioIcon() {
    if (!this.hasAudioIconTarget) return

    if (this.audioPlaying) {
      // Speaker with sound waves
      this.audioIconTarget.innerHTML = `
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z"></path>
      `
    } else {
      // Speaker muted
      this.audioIconTarget.innerHTML = `
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z"></path>
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2"></path>
      `
    }
  }

  disconnect() {
    this.stop()
    if (this.hasAudioTarget) {
      this.audioTarget.pause()
    }
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
    this.currentIndex = -1 // Start with title slide

    this.closeConfig()
    this.showSlideshow()
    this.showTitleSlide()
    this.startTimer()
  }

  showTitleSlide() {
    const wasShowingImage = !this.imageAreaTarget.classList.contains("hidden")

    // Populate title slide content
    this.galleryTitleTarget.textContent = this.galleryTitleValue || "Untitled Album"
    this.galleryDescriptionTarget.textContent = this.galleryDescriptionValue || ""
    this.photoCountTarget.textContent = `${this.imagesValue.length} photos`
    this.counterTarget.textContent = ""

    // If coming from image, fade out image first then show title
    if (wasShowingImage) {
      this.imageTarget.style.transition = "opacity 0.3s ease"
      this.imageTarget.style.opacity = "0"
      setTimeout(() => {
        this.imageAreaTarget.classList.add("hidden")
        if (this.hasInfoBarTarget) this.infoBarTarget.classList.add("hidden")
        this.imageTarget.style.transition = ""

        // Fade in title slide
        this.titleSlideTarget.style.opacity = "0"
        this.titleSlideTarget.classList.remove("hidden")
        setTimeout(() => {
          this.titleSlideTarget.style.transition = "opacity 0.5s ease"
          this.titleSlideTarget.style.opacity = "1"
          setTimeout(() => {
            this.titleSlideTarget.style.transition = ""
          }, 500)
        }, 50)
      }, 300)
    } else {
      // Initial show - no transition needed
      this.titleSlideTarget.classList.remove("hidden")
      this.imageAreaTarget.classList.add("hidden")
      if (this.hasInfoBarTarget) this.infoBarTarget.classList.add("hidden")
    }
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

    // Stop audio
    if (this.hasAudioTarget) {
      this.audioTarget.pause()
      this.audioPlaying = false
    }
  }

  showImage(withTransition = true) {
    // If on title slide index, show title slide
    if (this.currentIndex === -1) {
      this.showTitleSlide()
      return
    }

    const img = this.imagesValue[this.currentIndex]
    if (!img) return

    const wasOnTitleSlide = !this.titleSlideTarget.classList.contains("hidden")

    // Hide title slide, show image area and info bar
    this.titleSlideTarget.classList.add("hidden")
    this.imageAreaTarget.classList.remove("hidden")
    if (this.hasInfoBarTarget) this.infoBarTarget.classList.remove("hidden")

    // Update photo info
    this.titleTarget.textContent = img.title || ""
    this.captionTarget.textContent = img.caption || ""
    this.dateTakenTarget.textContent = img.date_taken ? this.formatDate(img.date_taken) : ""
    this.counterTarget.textContent = `${this.currentIndex + 1} / ${this.imagesValue.length}`

    // Coming from title slide - just fade in the first image
    if (wasOnTitleSlide) {
      this.imageTarget.style.opacity = "0"
      this.imageTarget.src = this.getImageSrc(img)
      this.imageTarget.onload = () => {
        this.imageTarget.style.transition = "opacity 0.5s ease"
        this.imageTarget.style.opacity = "1"
        setTimeout(() => {
          this.imageTarget.style.transition = ""
        }, 500)
      }
      return
    }

    if (withTransition) {
      this.applyTransition(() => {
        this.imageTarget.src = this.getImageSrc(img)
      })
    } else {
      this.imageTarget.src = this.getImageSrc(img)
    }
  }

  formatDate(dateStr) {
    if (!dateStr) return ""
    const date = new Date(dateStr)
    return date.toLocaleDateString(undefined, { year: "numeric", month: "long", day: "numeric" })
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
      // Hide image completely while loading new src
      img.style.visibility = "hidden"
      img.classList.remove("fade-out", "slide-out-left", "slide-out-right", "zoom-out")

      loadNewImage()

      // Wait for image to load, then animate in
      const onImageReady = () => {
        img.style.visibility = "visible"
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
        }, 1000)
      }

      img.onload = onImageReady

      // Fallback if image already cached (onload may not fire)
      if (img.complete) {
        onImageReady()
      }
    }, 600)
  }

  next() {
    // -1 (title) -> 0 -> 1 -> ... -> length-1 -> -1 (loop back to title)
    this.currentIndex++
    if (this.currentIndex >= this.imagesValue.length) {
      this.currentIndex = -1
    }
    this.showImage()
  }

  prev() {
    // ... -> 1 -> 0 -> -1 (title) -> length-1 -> ...
    this.currentIndex--
    if (this.currentIndex < -1) {
      this.currentIndex = this.imagesValue.length - 1
    }
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
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }
    if (this.timer) {
      this.stopTimer()
      this.pauseBtnTarget.innerHTML = this.playIcon()
    } else {
      this.startTimer()
      this.pauseBtnTarget.innerHTML = this.pauseIcon()
    }
  }

  playIcon() {
    return `<svg class="w-8 h-8" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>`
  }

  pauseIcon() {
    return `<svg class="w-8 h-8" fill="currentColor" viewBox="0 0 24 24"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>`
  }

  // Save Modal Methods
  openSaveModal(event) {
    if (event) event.preventDefault()
    if (this.imagesValue.length === 0) {
      alert("No photos in this gallery")
      return
    }
    this.saveModalTarget.classList.remove("hidden")
    this.saveTitleInputTarget.focus()
  }

  closeSaveModal(event) {
    if (event) event.preventDefault()
    this.saveModalTarget.classList.add("hidden")
  }

  async saveSlideshow(event) {
    event.preventDefault()

    const title = this.saveTitleInputTarget.value.trim()
    if (!title) {
      alert("Please enter a title")
      return
    }

    // Use FormData for file upload support
    const formData = new FormData()
    formData.append('slideshow[title]', title)
    formData.append('slideshow[description]', this.saveDescriptionInputTarget.value.trim())
    formData.append('slideshow[interval]', parseInt(this.saveIntervalInputTarget.value) || 5)

    // Add audio file if selected
    if (this.hasSaveAudioInputTarget && this.saveAudioInputTarget.files[0]) {
      formData.append('slideshow[audio]', this.saveAudioInputTarget.files[0])
    }

    // Add upload IDs
    this.imagesValue.forEach(img => {
      formData.append('upload_ids[]', img.id)
    })

    try {
      const response = await fetch('/slideshows', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: formData
      })

      if (response.ok) {
        const result = await response.json()
        window.location.href = result.redirect
      } else {
        const error = await response.json()
        alert(error.errors ? error.errors.join(", ") : "Failed to save slideshow")
      }
    } catch (error) {
      alert("Failed to save slideshow")
    }
  }

  keydown(event) {
    // Save modal open
    if (this.hasSaveModalTarget && !this.saveModalTarget.classList.contains("hidden")) {
      if (event.key === "Escape") this.closeSaveModal()
      return
    }

    // Config modal open
    if (this.hasConfigModalTarget && !this.configModalTarget.classList.contains("hidden")) {
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
        case "m":
          this.toggleAudio()
          break
      }
    }
  }

  stopPropagation(event) {
    event.stopPropagation()
  }
}
