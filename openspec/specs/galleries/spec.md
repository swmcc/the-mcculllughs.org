# Galleries Domain Specification

## Overview

The galleries domain manages photo galleries that organize uploaded media. Each gallery belongs to a user and contains multiple uploads.

## Requirements

### REQ-GAL-001: Gallery Model

A Gallery MUST have the following attributes:
- `title` (string, required)
- `description` (text, optional)
- `user_id` (foreign key, required)
- `created_at` (timestamp)
- `updated_at` (timestamp)

### REQ-GAL-002: Gallery Associations

A Gallery MUST belong to a User.

A Gallery MUST have many Uploads.

When a Gallery is destroyed, all associated Uploads MUST be destroyed.

### REQ-GAL-003: Gallery Listing

The system MUST display galleries in reverse chronological order (most recent first).

The gallery listing MUST include eager loading of the user association to prevent N+1 queries.

### REQ-GAL-004: Gallery Creation

Only authenticated users MUST be able to create galleries.

A new gallery MUST be automatically associated with the current user.

### REQ-GAL-005: Gallery CRUD Operations

The system MUST provide full CRUD operations for galleries:
- Create: Add new gallery with title and description
- Read: View gallery details and its uploads
- Update: Edit gallery title and description
- Delete: Remove gallery and all associated uploads

### REQ-GAL-006: Response Formats

Gallery controllers MUST respond to:
- HTML format (standard page rendering)
- Turbo Stream format (for dynamic updates)

## Scenarios

### SCENARIO: List All Galleries

**Given** an authenticated user
**When** they visit the galleries index page
**Then** all galleries SHALL be displayed
**And** galleries SHALL be ordered by creation date (newest first)
**And** each gallery SHALL display its title and creator

### SCENARIO: View Gallery Details

**Given** an authenticated user
**And** an existing gallery with uploads
**When** they view the gallery
**Then** the gallery title and description SHALL be displayed
**And** all uploads in the gallery SHALL be displayed
**And** uploads SHALL be ordered by creation date (newest first)
**And** an upload form SHALL be available

### SCENARIO: Create New Gallery

**Given** an authenticated user on the new gallery page
**When** they submit a valid title
**Then** a new gallery SHALL be created
**And** the gallery SHALL be associated with the current user
**And** the user SHALL be redirected to the gallery page
**And** a success notice SHALL be displayed

### SCENARIO: Create Gallery Without Title

**Given** an authenticated user on the new gallery page
**When** they submit without a title
**Then** the gallery SHALL NOT be created
**And** a validation error SHALL be displayed
**And** the user SHALL remain on the new gallery form

### SCENARIO: Edit Gallery

**Given** an authenticated user
**And** an existing gallery
**When** they update the gallery title or description
**Then** the gallery SHALL be updated
**And** the user SHALL be redirected to the gallery page
**And** a success notice SHALL be displayed

### SCENARIO: Delete Gallery

**Given** an authenticated user
**And** an existing gallery with uploads
**When** they delete the gallery
**Then** the gallery SHALL be destroyed
**And** all associated uploads SHALL be destroyed
**And** the user SHALL be redirected to the galleries index
**And** a success notice SHALL be displayed

### SCENARIO: Turbo Stream Create

**Given** an authenticated user
**When** they create a gallery via Turbo Stream
**Then** the new gallery SHALL appear dynamically without page reload

### SCENARIO: Turbo Stream Delete

**Given** an authenticated user
**When** they delete a gallery via Turbo Stream
**Then** the gallery SHALL be removed dynamically without page reload
