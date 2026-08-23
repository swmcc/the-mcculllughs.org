# The McCulloughs - Project Conventions

## Overview

A private family photo and video sharing application built with Rails 8. It provides
Devise authentication, photo galleries, drag-and-drop media uploads with automatic
WebP variant generation and EXIF extraction, date-based timeline browsing, text search,
saved slideshows, public share links, external photo imports (Flickr), and a JSON API
used by an external "Indexatron" analysis service. Mobile-first, dark-themed design.

## Tech Stack

| Component | Technology |
|-----------|------------|
| Framework | Rails ~> 8.1.3 |
| Ruby Version | 3.4.4 (`.ruby-version`) |
| Database | PostgreSQL (with the `vector` extension) |
| Vector Search | pgvector via `neighbor` (`Upload#embedding`) |
| Authentication | Devise (sessions) + `ApiKey` bearer tokens (API) |
| Styling | TailwindCSS v4 |
| JavaScript | Hotwire (Turbo + Stimulus) |
| Asset Pipeline | Propshaft + Importmap (no Node build step) |
| File Storage | Active Storage (local disk in dev, S3-compatible in production) |
| Image Processing | `image_processing` ~> 2.0 + `ruby-vips` ~> 2.2 (libvips) |
| EXIF Metadata | `mini_exiftool` (requires the `exiftool` binary) |
| External Imports | `oauth` ~> 1.1 (OAuth 1.0a, Flickr), `oauth2` ~> 2.0 |
| Background Jobs | Solid Queue (database-backed) |
| Caching | Solid Cache |
| Testing | RSpec, Factory Bot, Shoulda Matchers, Capybara |
| Linting / Security | rubocop-rails-omakase, Brakeman ~> 8.0.6 |
| Deployment | Hatchbox (Docker image built from `Dockerfile`) |

> `ruby-vips` is pinned explicitly because `image_processing` 2.0 dropped it as a
> dependency. libvips (and `exiftool`) must be installed anywhere the app boots --
> see `Brewfile`, `Dockerfile` and `.github/workflows/ci.yml`.

> `config/deploy.yml` is the untouched Kamal scaffold (placeholder image and server)
> and is *not* how this app is deployed. Treat it as unused.

## Architecture

### Domain Models

```
User (Devise)
  |-- role: enum (member, admin)
  |-- has_many :galleries, :uploads, :slideshows
  |-- has_many :external_connections, :imports, :api_keys

Gallery
  |-- belongs_to :user
  |-- belongs_to :cover_upload (class_name: Upload, optional)
  |-- has_many :uploads, :imports
  |-- title, description

Upload
  |-- belongs_to :user, :gallery
  |-- belongs_to :import (optional -- set for imported photos)
  |-- has_one_attached :file        # the only attachment; variants derive from this
  |-- has_neighbors :embedding      # pgvector(768), written by the API
  |-- title, caption, date_taken, exif_data, analysis_data
  |-- short_code (unique, auto-generated), is_public

Slideshow
  |-- belongs_to :user
  |-- has_many :slideshow_uploads (ordered by position) -> has_many :uploads
  |-- has_one_attached :audio
  |-- title, interval (1..60 seconds), short_code (unique, auto-generated)

SlideshowUpload
  |-- belongs_to :slideshow, :upload
  |-- position (join model that orders a slideshow)

ExternalConnection
  |-- belongs_to :user
  |-- has_many :imports
  |-- provider: flickr | google | facebook (unique per user)
  |-- encrypts :access_token, :access_secret, :refresh_token, :api_key, :api_secret

Import
  |-- belongs_to :user; belongs_to :gallery, :external_connection (optional)
  |-- has_many :uploads
  |-- provider, external_album_id (unique per user+provider)
  |-- status: pending | in_progress | completed | failed
  |-- total_photos, imported_count, failed_count, error_message

ApiKey
  |-- belongs_to :user
  |-- key ("sk_" + 64 hex chars, auto-generated), name
  |-- scope: admin | photos:create
  |-- expires_at, revoked_at, last_used_at
```

### Key Architectural Patterns

1. **Authentication**: `ApplicationController` applies `before_action :authenticate_user!`
   globally. Six controllers opt out via `skip_before_action :authenticate_user!` and are
   all security-sensitive: `HomeController` (landing page), `PagesController` (about,
   colophon), `TimelineController`, `PublicPhotosController`, `PublicSlideshowsController`,
   and `Api::BaseController` (API-key auth instead). Verify the current list with
   `grep -rn "skip_before_action :authenticate_user!" app/controllers/` before assuming.
2. **Role-based Authorization**: Users are `member` or `admin`. `require_admin!` lives on
   `ApplicationController` and is applied by `Admin::BaseController`.
3. **Media Processing**: `ProcessMediaJob` runs `after_commit :process_media, on: :create`.
   For images it pre-generates three Active Storage **WebP variants** and extracts EXIF
   into `exif_data`, backfilling `date_taken` from `DateTimeOriginal`. Video handling is
   a logging placeholder (no ffmpeg wired up).

   | Variant | Transform | Format |
   |---------|-----------|--------|
   | `thumb` | `resize_to_fill: [400, 400]` | WebP, quality 80, stripped |
   | `medium` | `resize_to_limit: [1024, 1024]` | WebP, quality 80, stripped |
   | `large` | `resize_to_limit: [2048, 2048]` | WebP, quality 80, stripped |

   Sizes are defined once in `ProcessMediaJob::VARIANTS` and read back by
   `UploadsHelper#upload_variant_url` / `#upload_picture_tag`, which renders a
   `<picture>` with a WebP source and the original as fallback. The original file is
   always kept for download. There is **no** `thumbnail` attachment -- the legacy
   association was removed; `rake uploads:purge_legacy_thumbnails` purges any orphaned
   blobs from storage.
4. **Public Sharing** (no auth -- security-sensitive): every `Upload` and `Slideshow`
   gets a random `short_code` at creation (6 alphanumeric chars for uploads, 8 lowercase
   for slideshows). Photo sharing is opt-in via `Upload#is_public`; slideshow sharing is
   not -- see the `/s/` bullet below.
   - `GET /p/:short_code` -- public photo page. Visible when the upload is public, or to
     the gallery owner / an admin (who see an unshared photo in order to share it).
   - `PATCH /p/:short_code` -- toggles `is_public`; owner or admin only, 403 otherwise.
   - `GET /t/:short_code` -- 404s unless public, then redirects to the `thumb` variant
     (cached 1 year -- variant URLs are immutable).
   - `GET /s/:short_code` -- public slideshow. **Not gated on `is_public`**: unlike photos,
     a slideshow is reachable by anyone holding its `short_code`, and it renders every
     upload it contains regardless of that upload's `is_public` flag (it also increments
     `view_count` on each view). Adding a private upload to a slideshow therefore exposes
     it. Photo sharing is opt-in; slideshow sharing is capability-by-URL.
5. **Timeline**: `TimelineController` is also unauthenticated and scoped to
   `is_public: true` uploads with a non-nil `date_taken`. It browses a
   decade -> year -> month hierarchy, with routes constrained by regex
   (`/\d{4}s/`, `/\d{4}/`, `/\d{1,2}/`).
6. **Search**: `SearchService` (called by `SearchController`) delegates to `QueryParser`,
   which pulls a date range out of natural-language queries ("summer 1998", "july 2019").
   It ILIKEs `title`/`caption`, then degrades gracefully -- text+date, then text only,
   then the raw query -- capped at 100 results. Admins search everything; members only
   uploads in their own galleries.
7. **Slideshows**: user-curated, ordered sets of uploads (`SlideshowUpload#position`)
   with a slide `interval` (1-60 seconds) and an optional attached audio track; built
   in-browser via the `slideshow_editor` and `photo_picker` Stimulus controllers.
8. **External Imports**: `ImportsController` runs the OAuth dance, stores tokens in an
   encrypted `ExternalConnection`, then enqueues `ImportAlbumJob` (queue `:imports`) which
   pages through an album and hands each photo to `PhotoImporter`. Providers subclass
   `ImportProviders::Base`. **Only Flickr is implemented** -- `google` and `facebook` are
   valid `ExternalConnection` providers and are dispatched by `ImportAlbumJob`, but the
   provider classes do not exist yet, so selecting them raises.
9. **JSON API** (`api/` namespace, for the external Indexatron service and an Apple
   Shortcut): `Api::BaseController` skips Devise and authenticates a
   `Authorization: Bearer sk_...` token against `ApiKey.active`. Endpoints are
   **admin-scope by default**; subclasses opt individual actions down to a lesser scope.
   - `GET /api/uploads/pending` -- uploads with no `analysis_data` (paginated, max 100)
   - `GET /api/uploads/:short_code` -- single upload with metadata + medium variant URL
   - `PATCH /api/uploads/:id/analysis` -- write `analysis_data` and the pgvector `embedding`
   - `POST /api/uploads` -- `photos:create` scope, rate-limited to 60/min per key,
     idempotent by blob checksum within a gallery; falls back to a "Shortcuts Inbox" gallery
   - `GET /api/galleries` -- gallery list
   Keys are self-served at `/api_keys`; the raw token is passed through the flash and
   shown exactly once after creation. Deleting a key **revokes** it (sets `revoked_at`)
   rather than destroying the row, so `last_used_at` history survives.
10. **Multi-format Responses**: Controllers respond to HTML, Turbo Stream, and JSON.
11. **Stimulus Controllers**: All interactivity is Stimulus -- see the directory below.

### Directory Structure

```
app/
  controllers/
    application_controller.rb    # Base controller with auth
    home_controller.rb           # Public landing / logged-in redirect
    dashboard_controller.rb      # Logged-in home
    galleries_controller.rb      # Gallery CRUD
    uploads_controller.rb        # Upload create/update/destroy, set_cover
    timeline_controller.rb       # Decade/year/month browsing
    search_controller.rb         # Text + date search
    slideshows_controller.rb     # Saved slideshows
    imports_controller.rb        # OAuth connect + album import
    api_keys_controller.rb       # Self-service API key management
    public_photos_controller.rb      # /p/:short_code, /t/:short_code (no auth)
    public_slideshows_controller.rb  # /s/:short_code (no auth)
    pages_controller.rb          # about, colophon
    admin/                       # base_controller, users_controller (+ galleries, uploads)
    api/                         # base_controller (API-key auth), uploads, galleries
    users/registrations_controller.rb  # Devise override
  models/
    user.rb gallery.rb upload.rb
    slideshow.rb slideshow_upload.rb
    import.rb external_connection.rb api_key.rb
  services/
    search_service.rb            # Search orchestration + scoping
    query_parser.rb              # Natural-language date extraction
    photo_importer.rb            # Download one external photo -> Upload
    import_providers/
      base.rb                    # Provider interface
      flickr_provider.rb         # Flickr OAuth 1.0a (only implemented provider)
  jobs/
    process_media_job.rb         # WebP variants + EXIF extraction
    import_album_job.rb          # Paged album import (queue: :imports)
  helpers/
    uploads_helper.rb            # upload_variant_url, upload_picture_tag
  javascript/
    controllers/
      dropzone_controller.js         # Drag-and-drop uploads
      lightbox_controller.js         # Full-screen photo viewer
      slideshow_controller.js        # Slideshow playback
      slideshow_editor_controller.js # Reorder/edit slideshows
      photo_picker_controller.js     # Pick uploads for a slideshow
      search_lightbox_controller.js  # Search overlay
      import_status_controller.js    # Poll import progress
      public_toggle_controller.js    # Toggle Upload#is_public
      dropdown_controller.js notification_controller.js
lib/tasks/
  storage.rake                   # Pull S3 blobs down to local storage
  uploads.rake variants.rake     # Upload/variant maintenance
spec/                            # The real test suite (test/ is empty scaffolding)
openspec/specs/                  # Domain specs: authentication, galleries, uploads
```

## Git Commit Conventions

Use gitmoji format for commit messages. See https://gitmoji.dev/

| Emoji | Code | Usage |
|-------|------|-------|
| :sparkles: | `:sparkles:` | New feature |
| :bug: | `:bug:` | Bug fix |
| :recycle: | `:recycle:` | Refactor code |
| :lipstick: | `:lipstick:` | UI/style updates |
| :art: | `:art:` | Improve structure/format |
| :zap: | `:zap:` | Performance improvement |
| :lock: | `:lock:` | Security fix |
| :white_check_mark: | `:white_check_mark:` | Add/update tests |
| :memo: | `:memo:` | Documentation |
| :wrench: | `:wrench:` | Configuration changes |
| :heavy_plus_sign: | `:heavy_plus_sign:` | Add dependency |
| :heavy_minus_sign: | `:heavy_minus_sign:` | Remove dependency |
| :truck: | `:truck:` | Move/rename files |
| :fire: | `:fire:` | Remove code/files |
| :construction: | `:construction:` | Work in progress |
| :tada: | `:tada:` | Initial commit |

### Commit Message Format

```
:emoji: Short description (50 chars max)

Longer description if needed. Explain what and why,
not how (the code shows how).
```

## Code Conventions

### Ruby/Rails

- Follow Rails Omakase conventions (rubocop-rails-omakase)
- Use strong parameters for all controller inputs
- Prefer scopes over class methods for queries
- Use `dependent: :destroy` for cascading deletes
- Use enums for fixed-value fields (e.g., roles)

### Models

```ruby
class Model < ApplicationRecord
  # 1. Includes/Extends
  # 2. Constants
  # 3. Associations
  # 4. Validations
  # 5. Callbacks
  # 6. Scopes
  # 7. Class methods
  # 8. Instance methods
  # 9. Private methods
end
```

### Controllers

```ruby
class ThingsController < ApplicationController
  before_action :set_thing, only: [:show, :edit, :update, :destroy]

  # CRUD actions in order: index, show, new, create, edit, update, destroy

  private

  def set_thing
    @thing = Thing.find(params[:id])
  end

  def thing_params
    params.require(:thing).permit(:allowed, :attributes)
  end
end
```

### JavaScript (Stimulus)

- Use Stimulus controllers for interactive behavior
- Define targets and values at top of controller
- Keep controllers focused on single responsibility
- Use data attributes for configuration

### Testing

- Use RSpec for all tests
- Use Factory Bot for test data
- Use Shoulda Matchers for model validations
- Test happy path and edge cases
- Keep tests focused and readable

## Commands

### Development

```bash
# Setup (install deps, create db, migrate, seed)
make local.setup

# Start development server (Rails + Solid Queue)
make local.run
# or
bin/dev

# Rails console
make console
```

### Database

```bash
make local.db.migrate    # Run migrations
make local.db.rollback   # Rollback last migration
make local.db.seed       # Seed database
make local.db.reset      # Drop, create, migrate, seed
make local.db.status     # Check migration status
```

### Testing

```bash
make local.test          # Run all RSpec tests
make local.test.fast     # Run tests without coverage
make local.test.models   # Run model tests only
make local.test.requests # Run request tests only
make local.test.jobs     # Run job tests only
```

### Code Quality

```bash
make lint                # Run RuboCop
make lint.fix            # Auto-fix RuboCop issues
make local.brakeman      # Security analysis
make deploy.check        # Lint + Brakeman + Tests
```

### Assets

```bash
make tailwind.build      # Build Tailwind CSS
make tailwind.watch      # Watch and rebuild CSS
make assets.build        # Compile all assets
make assets.clean        # Clean compiled assets
```

### Background Jobs

```bash
make jobs.start          # Start Solid Queue processor
make jobs.status         # Show queue status
```

## Environment Variables

There is no `.env.example` checked in; `dotenv-rails` loads `.env` if present.
These are the variables the code actually reads:

| Variable | Used by | Description |
|----------|---------|-------------|
| `DATABASE_URL` | `config/database.yml` | Production DB (cache/queue DBs derive from it) |
| `S3_ACCESS_KEY_ID` | `config/storage.yml` (`spaces`) | S3-compatible storage key |
| `S3_SECRET_ACCESS_KEY` | `config/storage.yml` (`spaces`) | S3-compatible storage secret |
| `S3_REGION` | `config/storage.yml` (`spaces`) | Region (e.g. `nyc3`) |
| `S3_BUCKET` | `config/storage.yml` | Bucket name |
| `S3_ENDPOINT` | `config/storage.yml` (`spaces`) | Endpoint URL (DigitalOcean Spaces) |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_REGION` | `config/storage.yml` (`amazon`) | Only for the unused `amazon` service |
| `CDN_HOST` | Production config | Optional asset/CDN host |
| `RAILS_MAX_THREADS`, `WEB_CONCURRENCY`, `JOB_CONCURRENCY`, `PORT`, `SOLID_QUEUE_IN_PUMA`, `RAILS_LOG_LEVEL` | Puma / Solid Queue | Standard Rails 8 runtime tuning |

`ExternalConnection` encrypts its OAuth tokens, so Active Record encryption keys must be
set in Rails credentials (`make credentials.edit`).

Local development uses the `the_mcculloughs_org_development` database with no password
by default. Flickr API credentials are stored per-user in `ExternalConnection`, not in ENV.

## Default Credentials (Development)

- **Admin**: `admin@the-mcculloughs.org` / `password123`
- **Member 1**: `john@the-mcculloughs.org` / `password123`
- **Member 2**: `jane@the-mcculloughs.org` / `password123`
