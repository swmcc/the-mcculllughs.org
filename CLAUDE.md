# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Family photo sharing application built with Rails 8, PostgreSQL, TailwindCSS v4, and Hotwire (Turbo + Stimulus). Uses Solid Queue for background jobs (database-backed, no Redis needed for jobs).

## Common Commands

### Development
```bash
bin/dev                          # Start Rails + Tailwind watcher + Solid Queue
bundle exec rspec                # Run all tests
bundle exec rspec spec/models    # Run model tests only
bundle exec rspec spec/requests  # Run request tests only
bundle exec rspec spec/path/to/file_spec.rb  # Single test file
bundle exec rubocop              # Lint
bundle exec rubocop -A           # Auto-fix lint issues
bin/brakeman --exit-on-warn      # Security analysis
```

### Database
```bash
rails db:migrate                 # Run migrations
rails db:reset                   # Drop, create, migrate, seed
rails db:seed                    # Seed with test users
```

### Assets
```bash
rails tailwindcss:build          # Rebuild Tailwind CSS
```

### Makefile shortcuts
```bash
make help                        # Show all available targets
make local.run                   # Start app (same as bin/dev)
make local.test                  # Run tests
make lint.fix                    # Auto-fix rubocop issues
```

## Architecture

### Core Domain Models
- **User** - Devise authentication with `role` enum (`member: 0`, `admin: 1`)
- **Gallery** - Photo albums, belongs_to User
- **Upload** - Media files (photos/videos) with Active Storage, belongs_to Gallery and User

### File Storage
- Active Storage with two attachments per Upload: `file` (original) and `thumbnail` (generated)
- Development: local disk storage
- Production: S3-compatible storage (DigitalOcean Spaces)

### Background Jobs
- **ProcessMediaJob** - Generates thumbnails for uploaded images using ImageProcessing + MiniMagick
- Queued via Solid Queue (runs when `bin/dev` starts or `rake solid_queue:start`)
- Upload model triggers job via `after_commit :process_media, on: :create`

### Frontend
- Hotwire: Turbo for SPA-like navigation, Stimulus for JS controllers
- Stimulus controllers in `app/javascript/controllers/`
- `dropzone_controller.js` handles drag-and-drop file uploads

### Routes Structure
```
/                              # galleries#index (root)
/galleries                     # CRUD for galleries
/galleries/:id/uploads         # Nested uploads (create only)
/uploads/:id                   # Delete uploads
/admin/*                       # Admin namespace (dashboard, users, galleries, uploads)
```

## Testing

Uses RSpec with:
- Factory Bot for fixtures (`spec/factories/`)
- Shoulda Matchers for model validations
- Devise test helpers included for request specs

To authenticate in request specs:
```ruby
sign_in create(:user)
```
