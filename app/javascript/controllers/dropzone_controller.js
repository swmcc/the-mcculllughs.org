import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "dropzone", "form"]
  static values = {
    maxFiles: { type: Number, default: 10 },
    maxSize: { type: Number, default: 10485760 } // 10MB default
  }

  connect() {
    this.files = []
    this.setupDragAndDrop()
  }

  setupDragAndDrop() {
    const dropzone = this.dropzoneTarget

    // Prevent default drag behaviors
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      dropzone.addEventListener(eventName, this.preventDefaults, false)
      document.body.addEventListener(eventName, this.preventDefaults, false)
    })

    // Highlight drop zone when item is dragged over it
    ['dragenter', 'dragover'].forEach(eventName => {
      dropzone.addEventListener(eventName, () => this.highlight(), false)
    })

    ['dragleave', 'drop'].forEach(eventName => {
      dropzone.addEventListener(eventName, () => this.unhighlight(), false)
    })

    // Handle dropped files
    dropzone.addEventListener('drop', (e) => this.handleDrop(e), false)
  }

  preventDefaults(e) {
    e.preventDefault()
    e.stopPropagation()
  }

  highlight() {
    this.dropzoneTarget.classList.add('border-blue-500', 'bg-blue-500/10')
  }

  unhighlight() {
    this.dropzoneTarget.classList.remove('border-blue-500', 'bg-blue-500/10')
  }

  handleDrop(e) {
    const dt = e.dataTransfer
    const files = dt.files
    this.handleFiles(files)
  }

  // Handle file input change
  handleFileSelect(e) {
    const files = e.target.files
    this.handleFiles(files)
  }

  handleFiles(files) {
    // Convert FileList to Array
    const filesArray = [...files]

    // Validate files
    const validFiles = filesArray.filter(file => {
      if (file.size > this.maxSizeValue) {
        this.showError(`${file.name} is too large. Max size is ${this.formatBytes(this.maxSizeValue)}`)
        return false
      }
      if (!file.type.match('image.*') && !file.type.match('video.*')) {
        this.showError(`${file.name} is not an image or video`)
        return false
      }
      return true
    })

    if (validFiles.length === 0) return

    // Add to files array
    this.files = [...this.files, ...validFiles].slice(0, this.maxFilesValue)

    // Show previews
    this.showPreviews()
  }

  showPreviews() {
    this.previewTarget.innerHTML = ''

    this.files.forEach((file, index) => {
      const reader = new FileReader()

      reader.onload = (e) => {
        const preview = document.createElement('div')
        preview.className = 'relative group aspect-square bg-neutral-800 rounded-lg overflow-hidden border border-white/10'

        if (file.type.match('image.*')) {
          preview.innerHTML = `
            <img src="${e.target.result}" class="w-full h-full object-cover" alt="${file.name}" />
            <div class="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
              <button type="button" data-action="click->dropzone#removeFile" data-index="${index}" class="p-2 bg-red-600 hover:bg-red-700 rounded-lg transition-colors">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                </svg>
              </button>
            </div>
            <div class="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/80 to-transparent p-2">
              <p class="text-white text-xs truncate">${file.name}</p>
              <p class="text-white/60 text-xs">${this.formatBytes(file.size)}</p>
            </div>
          `
        } else if (file.type.match('video.*')) {
          preview.innerHTML = `
            <div class="w-full h-full flex items-center justify-center bg-neutral-900">
              <svg class="w-12 h-12 text-white/30" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"></path>
              </svg>
            </div>
            <div class="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
              <button type="button" data-action="click->dropzone#removeFile" data-index="${index}" class="p-2 bg-red-600 hover:bg-red-700 rounded-lg transition-colors">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                </svg>
              </button>
            </div>
            <div class="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/80 to-transparent p-2">
              <p class="text-white text-xs truncate">${file.name}</p>
              <p class="text-white/60 text-xs">${this.formatBytes(file.size)}</p>
            </div>
          `
        }

        this.previewTarget.appendChild(preview)
      }

      reader.readAsDataURL(file)
    })

    // Show upload button if files selected
    if (this.files.length > 0) {
      this.showUploadButton()
    }
  }

  removeFile(e) {
    const index = parseInt(e.currentTarget.dataset.index)
    this.files.splice(index, 1)
    this.showPreviews()

    if (this.files.length === 0) {
      this.hideUploadButton()
    }
  }

  showUploadButton() {
    const uploadBtn = this.element.querySelector('[data-dropzone-upload]')
    if (uploadBtn) {
      uploadBtn.classList.remove('hidden')
    }
  }

  hideUploadButton() {
    const uploadBtn = this.element.querySelector('[data-dropzone-upload]')
    if (uploadBtn) {
      uploadBtn.classList.add('hidden')
    }
  }

  upload(e) {
    e.preventDefault()

    if (this.files.length === 0) {
      this.showError('Please select at least one file')
      return
    }

    // Get form data
    const form = this.formTarget
    const formData = new FormData(form)

    // Remove the default file input data
    formData.delete('upload[file]')

    // Add all files
    this.files.forEach(file => {
      formData.append('upload[file]', file)
    })

    // Show uploading state
    this.showUploading()

    // Submit via fetch
    fetch(form.action, {
      method: 'POST',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        'Accept': 'text/vnd.turbo-stream.html'
      }
    })
    .then(response => {
      if (response.ok) {
        // Reset form
        this.files = []
        this.previewTarget.innerHTML = ''
        this.hideUploadButton()
        this.hideUploading()

        // Reload the page to show new uploads
        window.location.reload()
      } else {
        throw new Error('Upload failed')
      }
    })
    .catch(error => {
      this.showError('Upload failed. Please try again.')
      this.hideUploading()
    })
  }

  showUploading() {
    const btn = this.element.querySelector('[data-dropzone-upload]')
    if (btn) {
      btn.disabled = true
      btn.innerHTML = `
        <svg class="animate-spin h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <span>Uploading...</span>
      `
    }
  }

  hideUploading() {
    const btn = this.element.querySelector('[data-dropzone-upload]')
    if (btn) {
      btn.disabled = false
      btn.innerHTML = `
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"></path>
        </svg>
        <span>Upload ${this.files.length} ${this.files.length === 1 ? 'file' : 'files'}</span>
      `
    }
  }

  showError(message) {
    // Create toast notification
    const toast = document.createElement('div')
    toast.className = 'fixed top-20 right-4 bg-red-500 text-white px-4 py-3 rounded-lg shadow-lg z-50 animate-slide-in'
    toast.textContent = message
    document.body.appendChild(toast)

    setTimeout(() => {
      toast.remove()
    }, 3000)
  }

  formatBytes(bytes, decimals = 2) {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const dm = decimals < 0 ? 0 : decimals
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i]
  }

  // Click to select files
  clickToSelect() {
    this.inputTarget.click()
  }
}
