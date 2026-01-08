# Uploads Domain Specification

## Overview

The uploads domain handles media file uploads (photos and videos), storage via Active Storage, and automatic thumbnail generation through background processing.

## Requirements

### REQ-UPL-001: Upload Model

An Upload MUST have the following attributes:
- `title` (string, optional)
- `caption` (text, optional)
- `user_id` (foreign key, required)
- `gallery_id` (foreign key, required)
- `created_at` (timestamp)
- `updated_at` (timestamp)

### REQ-UPL-002: Upload Associations

An Upload MUST belong to a User.

An Upload MUST belong to a Gallery.

An Upload MUST have one attached file (via Active Storage).

An Upload MUST have one attached thumbnail (via Active Storage).

### REQ-UPL-003: Upload Validation

An Upload MUST have a file attached.

An Upload MUST be associated with a valid user.

An Upload MUST be associated with a valid gallery.

### REQ-UPL-004: Multiple File Upload

The system MUST support uploading multiple files in a single request.

Each file MUST be processed as a separate Upload record.

### REQ-UPL-005: Drag-and-Drop Upload

The system MUST provide a drag-and-drop interface for file uploads via Stimulus.js.

The dropzone MUST:
- Accept image files (image/*)
- Accept video files (video/*)
- Reject other file types with an error message
- Enforce a maximum file size (default 10MB)
- Enforce a maximum file count (default 10 files)

### REQ-UPL-006: File Preview

The system MUST display file previews before upload.

Image files MUST show a thumbnail preview.

Video files MUST show a video icon placeholder.

Each preview MUST display the filename and file size.

### REQ-UPL-007: Background Processing

After an Upload is created, a background job MUST be enqueued for processing.

The ProcessMediaJob MUST:
- Generate a 400x400 thumbnail for image files
- Log processing for video files (placeholder for future implementation)

### REQ-UPL-008: Upload Scopes

The system MUST provide the following scopes:
- `recent`: Orders uploads by creation date (newest first)
- `images`: Filters to image content types
- `videos`: Filters to video content types

### REQ-UPL-009: Response Formats

Upload controllers MUST respond to:
- HTML format (standard page rendering with redirect)
- Turbo Stream format (for dynamic updates)
- JSON format (for AJAX uploads)

## Scenarios

### SCENARIO: Upload Single File

**Given** an authenticated user on a gallery page
**When** they select a single image file and submit
**Then** an Upload record SHALL be created
**And** the file SHALL be attached via Active Storage
**And** a ProcessMediaJob SHALL be enqueued
**And** the user SHALL be redirected to the gallery
**And** a success message SHALL be displayed

### SCENARIO: Upload Multiple Files

**Given** an authenticated user on a gallery page
**When** they select multiple image files and submit
**Then** an Upload record SHALL be created for each file
**And** each file SHALL be attached via Active Storage
**And** a ProcessMediaJob SHALL be enqueued for each upload
**And** a success message SHALL indicate the number of files uploaded

### SCENARIO: Drag-and-Drop Upload

**Given** an authenticated user on a gallery page
**When** they drag and drop image files onto the dropzone
**Then** file previews SHALL be displayed
**And** an upload button SHALL appear
**When** they click the upload button
**Then** all files SHALL be uploaded
**And** the page SHALL refresh to show new uploads

### SCENARIO: Upload Invalid File Type

**Given** an authenticated user on a gallery page
**When** they attempt to upload a non-image, non-video file
**Then** an error message SHALL be displayed
**And** the file SHALL NOT be uploaded

### SCENARIO: Upload Oversized File

**Given** an authenticated user on a gallery page
**When** they attempt to upload a file larger than the maximum size
**Then** an error message SHALL be displayed
**And** the file SHALL NOT be uploaded

### SCENARIO: Remove File from Preview

**Given** an authenticated user with files selected for upload
**When** they click the remove button on a file preview
**Then** the file SHALL be removed from the selection
**And** the preview SHALL be removed from the display

### SCENARIO: Thumbnail Generation

**Given** an image file has been uploaded
**When** the ProcessMediaJob runs
**Then** a 400x400 thumbnail SHALL be generated
**And** the thumbnail SHALL be attached to the Upload record

### SCENARIO: Delete Upload

**Given** an authenticated user
**And** an existing upload in a gallery
**When** they delete the upload
**Then** the Upload record SHALL be destroyed
**And** the attached file SHALL be purged
**And** the attached thumbnail SHALL be purged
**And** the user SHALL be redirected to the gallery
**And** a success message SHALL be displayed

### SCENARIO: Upload Failure

**Given** an authenticated user on a gallery page
**When** they attempt to upload and the save fails
**Then** an error message SHALL be displayed
**And** the user SHALL remain on the gallery page

### SCENARIO: Partial Upload Success

**Given** an authenticated user uploading multiple files
**When** some files succeed and some fail
**Then** a message SHALL indicate the success count
**And** a message SHALL indicate the failure count
