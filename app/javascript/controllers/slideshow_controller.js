import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "configModal", "image", "counter", "intervalInput", "title", "caption", "dateTaken", "pauseBtn", "titleSlide", "imageArea", "galleryTitle", "galleryDescription", "photoCount", "infoBar", "spotifyInput", "spotifyPlayer", "spotifyToggle", "spotifySearch", "spotifyResults", "spotifySpinner", "spotifySelected", "spotifySelectedImage", "spotifySelectedName", "spotifySelectedMeta"]
  static values = {
    images: Array,
    interval: { type: Number, default: 5 },
    galleryTitle: String,
    galleryDescription: String
  }

  // Available transitions
  transitions = ["fade", "slide-left", "slide-right", "zoom"]

  connect() {
    this.currentIndex = -1 // -1 = title slide, 0+ = photos
    this.timer = null
    this.lastTransition = null
    this.spotifyUrl = null
    this.spotifyVisible = true
    this.searchTimeout = null
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
    this.currentIndex = -1 // Start with title slide

    // Set up Spotify if URL provided
    this.setupSpotify()

    this.closeConfig()
    this.showSlideshow()
    this.showTitleSlide()
    this.startTimer()
  }

  setupSpotify() {
    const url = this.spotifyInputTarget.value.trim()
    if (!url) {
      this.spotifyPlayerTarget.classList.add("hidden")
      this.spotifyToggleTarget.classList.add("hidden")
      return
    }

    const embedUrl = this.convertToSpotifyEmbed(url)
    if (!embedUrl) {
      this.spotifyPlayerTarget.classList.add("hidden")
      this.spotifyToggleTarget.classList.add("hidden")
      return
    }

    // Create iframe
    this.spotifyPlayerTarget.innerHTML = `
      <iframe
        src="${embedUrl}"
        width="300"
        height="80"
        frameborder="0"
        allow="autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture"
        loading="lazy"
        class="rounded-xl">
      </iframe>
    `
    this.spotifyPlayerTarget.classList.remove("hidden")
    this.spotifyToggleTarget.classList.remove("hidden")
    this.spotifyVisible = true
  }

  convertToSpotifyEmbed(url) {
    // Convert Spotify URLs to embed format
    // https://open.spotify.com/playlist/ABC -> https://open.spotify.com/embed/playlist/ABC
    // https://open.spotify.com/album/ABC -> https://open.spotify.com/embed/album/ABC
    // https://open.spotify.com/track/ABC -> https://open.spotify.com/embed/track/ABC
    const match = url.match(/open\.spotify\.com\/(playlist|album|track)\/([a-zA-Z0-9]+)/)
    if (match) {
      return `https://open.spotify.com/embed/${match[1]}/${match[2]}?utm_source=generator&theme=0`
    }
    return null
  }

  toggleSpotify(event) {
    event.preventDefault()
    event.stopPropagation()
    this.spotifyVisible = !this.spotifyVisible
    if (this.spotifyVisible) {
      this.spotifyPlayerTarget.classList.remove("hidden")
      this.spotifyToggleTarget.classList.remove("text-white/30")
      this.spotifyToggleTarget.classList.add("text-white/70")
    } else {
      this.spotifyPlayerTarget.classList.add("hidden")
      this.spotifyToggleTarget.classList.add("text-white/30")
      this.spotifyToggleTarget.classList.remove("text-white/70")
    }
  }

  // Spotify search functionality
  searchSpotify(event) {
    const query = event.target.value.trim()

    // Debounce search
    clearTimeout(this.searchTimeout)

    if (query.length < 2) {
      this.spotifyResultsTarget.classList.add("hidden")
      return
    }

    this.spotifySpinnerTarget.classList.remove("hidden")

    this.searchTimeout = setTimeout(async () => {
      try {
        const response = await fetch(`/spotify/search?q=${encodeURIComponent(query)}&type=track`)
        const data = await response.json()

        if (data.error) {
          this.spotifyResultsTarget.innerHTML = `<p class="p-3 text-sm text-neutral-500">${data.error}</p>`
        } else if (data.results && data.results.length > 0) {
          this.renderSpotifyResults(data.results)
        } else {
          this.spotifyResultsTarget.innerHTML = `<p class="p-3 text-sm text-neutral-500">No songs found</p>`
        }

        this.spotifyResultsTarget.classList.remove("hidden")
      } catch (error) {
        this.spotifyResultsTarget.innerHTML = `<p class="p-3 text-sm text-red-500">Search failed</p>`
        this.spotifyResultsTarget.classList.remove("hidden")
      } finally {
        this.spotifySpinnerTarget.classList.add("hidden")
      }
    }, 300)
  }

  renderSpotifyResults(results) {
    this.spotifyResultsTarget.innerHTML = results.map(item => `
      <button type="button"
              class="w-full p-2 flex items-center gap-3 hover:bg-neutral-50 transition-colors text-left"
              data-action="click->slideshow#selectSpotifyResult"
              data-url="${item.url}"
              data-name="${this.escapeHtml(item.name)}"
              data-image="${item.image || ''}"
              data-artist="${this.escapeHtml(item.artist || '')}">
        <img src="${item.image || ''}" class="w-10 h-10 rounded object-cover bg-neutral-200" onerror="this.style.display='none'">
        <div class="flex-1 min-w-0">
          <p class="text-sm font-medium text-neutral-800 truncate">${this.escapeHtml(item.name)}</p>
          <p class="text-xs text-neutral-500 truncate">${this.escapeHtml(item.artist || '')}</p>
        </div>
      </button>
    `).join('')
  }

  selectSpotifyResult(event) {
    const button = event.currentTarget
    const url = button.dataset.url
    const name = button.dataset.name
    const image = button.dataset.image
    const artist = button.dataset.artist

    // Set the URL
    this.spotifyInputTarget.value = url

    // Show selected state
    this.spotifySelectedTarget.classList.remove("hidden")
    this.spotifyResultsTarget.classList.add("hidden")
    this.spotifySearchTarget.value = ""

    this.spotifySelectedImageTarget.src = image
    this.spotifySelectedNameTarget.textContent = name
    this.spotifySelectedMetaTarget.textContent = artist
  }

  clearSpotifySelection(event) {
    event.preventDefault()
    this.spotifyInputTarget.value = ""
    this.spotifySelectedTarget.classList.add("hidden")
    this.spotifySearchTarget.focus()
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
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

    // Clean up Spotify player
    this.spotifyPlayerTarget.innerHTML = ""
    this.spotifyPlayerTarget.classList.add("hidden")
    this.spotifyToggleTarget.classList.add("hidden")
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
      this.imageTarget.src = img.large || img.medium || img.original
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
        this.imageTarget.src = img.large || img.medium || img.original
      })
    } else {
      this.imageTarget.src = img.large || img.medium || img.original
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
