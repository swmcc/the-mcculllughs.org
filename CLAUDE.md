# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Private family photo and video sharing app built with Rails 8.1, PostgreSQL (with the
`vector` extension), TailwindCSS v4, and Hotwire (Turbo + Stimulus). Ruby 3.4.4. Uses
Solid Queue for background jobs and Solid Cache for caching — both database-backed, so no
Redis is needed for either.

Beyond galleries and uploads it also has: a date-based timeline, text + date search, saved
slideshows, public share links, external photo imports (Flickr), a JSON API for an external
"Indexatron" analysis service and an Apple Shortcut, and pgvector embeddings.

For the fuller picture — domain model diagram, architectural patterns, conventions — see
`openspec/project.md`. `openspec/AGENTS.md` has the agent quick reference.

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

The real test suite lives in `spec/` (RSpec). The `test/` directory is empty Rails
scaffolding — running Minitest proves nothing. Always verify with `bundle exec rspec`.

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
make deploy.check                # Lint + Brakeman + tests (run before pushing)
```

### System dependencies
`brew bundle` installs them (see `Brewfile`). The app will not boot or process media
without **libvips** (Active Storage variants) and **exiftool** (EXIF extraction).

## Architecture

### Core Domain Models
- **User** — Devise authentication with `role` enum (`member: 0`, `admin: 1`)
- **Gallery** — Photo albums, belongs_to User, optional `cover_upload`
- **Upload** — Media files (photos/videos) with Active Storage, belongs_to Gallery and User
- **Slideshow** / **SlideshowUpload** — Saved, ordered slideshows with optional audio
- **Import** / **ExternalConnection** — External photo imports and encrypted OAuth tokens
- **ApiKey** — Bearer tokens for the `api/` namespace, scoped `admin` or `photos:create`

### File Storage
- Active Storage. `Upload has_one_attached :file` — the original, always retained for download.
  It is the **only** attachment; the legacy `thumbnail` attachment has been removed
- Derived images are **Active Storage variants**, not stored attachments. Three WebP
  variants are pre-generated: `thumb` (400×400 fill), `medium` (1024 limit), `large`
  (2048 limit), all quality 80 and metadata-stripped
- Variant definitions live in one place — `ProcessMediaJob::VARIANTS`. Read them back
  through `UploadsHelper#upload_variant_url` / `#upload_picture_tag` rather than
  redefining transforms at call sites
- Development: local disk storage. Production: S3-compatible (DigitalOcean Spaces)

### Background Jobs
Queued via Solid Queue (runs when `bin/dev` starts, or `rake solid_queue:start`).

- **ProcessMediaJob** — for images, generates the three WebP variants via
  ImageProcessing + **ruby-vips/libvips**, then extracts EXIF with `mini_exiftool` into
  `exif_data` and backfills `date_taken` from `DateTimeOriginal`. Video handling is a
  logging placeholder — no ffmpeg is wired up. Each step rescues and logs, so a failure
  degrades rather than losing the upload. Triggered by `after_commit :process_media, on: :create`
- **ImportAlbumJob** (queue `:imports`) — pages through an external album and hands each
  photo to `PhotoImporter`, updating `Import` progress counters as it goes

> `ruby-vips` is pinned explicitly in the Gemfile because `image_processing` 2.0 dropped
> it as a dependency. libvips must be installed wherever the app boots (Brewfile,
> Dockerfile, CI) or variant generation breaks.

### Services
- **SearchService** + **QueryParser** — `QueryParser` extracts a date range from
  natural-language queries ("july 2019"); `SearchService` ILIKEs `title`/`caption`, then
  degrades (text+date → text only → raw query), capped at 100 results. Admins search all
  uploads; members only their own galleries
- **PhotoImporter** — downloads one external photo and builds the `Upload`, skipping
  anything already imported
- **ImportProviders::Base** / **FlickrProvider** — Flickr (OAuth 1.0a) is the only
  implemented provider. `google` and `facebook` are valid `ExternalConnection` providers
  and are dispatched by `ImportAlbumJob`, but those classes don't exist yet

### Frontend
- Hotwire: Turbo for SPA-like navigation, Stimulus for JS controllers
- Stimulus controllers in `app/javascript/controllers/`: `dropzone` (drag-and-drop uploads),
  `lightbox`, `slideshow`, `slideshow_editor`, `photo_picker`, `search_lightbox`,
  `import_status`, `public_toggle`, `dropdown`, `notification`
- Propshaft + Importmap — no Node build step

### Authentication surfaces
`ApplicationController` applies `before_action :authenticate_user!` globally. Six
controllers skip it (`grep -rn "skip_before_action :authenticate_user!" app/controllers/`),
so any change to them is security-sensitive:

| Controller | What's exposed |
|---|---|
| `HomeController` | Landing page; samples up to 500 `is_public` uploads (signed-in users redirect to `/dashboard`) |
| `PagesController` | Static about/colophon |
| `TimelineController` | Scoped to `is_public: true` uploads with a `date_taken` |
| `PublicPhotosController` | `is_public` gated — plus owner/admin may view an unshared photo in order to share it |
| `PublicSlideshowsController` | **Not** gated on `is_public` — anyone holding the 8-char `short_code` sees the slideshow and every upload in it, public or not |
| `Api::BaseController` | Authenticates `Authorization: Bearer sk_...` against `ApiKey.active` instead; admin scope by default, actions opting down |

Note the asymmetry: photo sharing is opt-in per upload, slideshow sharing is
capability-by-URL. A private upload added to a slideshow becomes reachable through it.

### Routes Structure
```
/                              # home#index (public landing / dashboard redirect)
/dashboard                     # dashboard#index (logged-in home)
/galleries                     # CRUD for galleries
/galleries/:id/uploads         # Nested uploads (create only)
/uploads/:id                   # Update/delete uploads, PATCH :id/set_cover
/timeline/:decade/:year/:month # Date-based browsing (no auth, public uploads only)
/search                        # Text + date search
/slideshows                    # Saved slideshows (+ add/remove/reorder members)
/imports                       # OAuth connect + album import per provider
/api_keys                      # Self-service API key management
/p/:short_code                 # Public photo page (no auth); PATCH toggles is_public
/t/:short_code                 # Public thumbnail redirect (no auth)
/s/:short_code                 # Public slideshow (no auth)
/api/*                         # JSON API, API-key auth (uploads, galleries)
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
