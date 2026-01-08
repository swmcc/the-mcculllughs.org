# The McCulloughs - Project Conventions

## Overview

A private family photo and video sharing application built with Rails 8. The application provides secure authentication, photo galleries, and media uploads with automatic thumbnail generation. It uses a mobile-first, dark-themed design optimized for family use.

## Tech Stack

| Component | Technology |
|-----------|------------|
| Framework | Rails 8.0.2 |
| Ruby Version | 3.3.0 |
| Database | PostgreSQL |
| Authentication | Devise |
| Styling | TailwindCSS v4 |
| JavaScript | Hotwire (Turbo + Stimulus) |
| Asset Pipeline | Propshaft + Importmap |
| File Storage | Active Storage (local/S3-compatible) |
| Image Processing | ImageProcessing + MiniMagick |
| Background Jobs | Solid Queue (database-backed) |
| Caching | Solid Cache |
| Testing | RSpec, Factory Bot, Shoulda Matchers |
| Deployment | Kamal (Docker) |

## Architecture

### Domain Models

```
User (Devise)
  |-- role: enum (member, admin)
  |-- has_many :galleries
  |-- has_many :uploads

Gallery
  |-- belongs_to :user
  |-- has_many :uploads
  |-- title, description

Upload
  |-- belongs_to :user
  |-- belongs_to :gallery
  |-- has_one_attached :file
  |-- has_one_attached :thumbnail
  |-- title, caption
```

### Key Architectural Patterns

1. **Authentication**: All routes require authentication via Devise (`before_action :authenticate_user!`)
2. **Role-based Authorization**: Users have `member` or `admin` roles; admin features protected by `require_admin!`
3. **Background Processing**: Media uploads trigger `ProcessMediaJob` for thumbnail generation
4. **Multi-format Responses**: Controllers respond to HTML, Turbo Stream, and JSON formats
5. **Stimulus Controllers**: Interactive features (e.g., drag-and-drop upload) use Stimulus.js

### Directory Structure

```
app/
  controllers/
    application_controller.rb  # Base controller with auth
    galleries_controller.rb    # Gallery CRUD
    uploads_controller.rb      # File upload handling
  models/
    user.rb                    # Devise user with roles
    gallery.rb                 # Photo gallery
    upload.rb                  # Media file with attachments
  jobs/
    process_media_job.rb       # Thumbnail generation
  javascript/
    controllers/
      dropzone_controller.js   # Drag-and-drop uploads
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

Required environment variables (see `.env.example`):

| Variable | Description |
|----------|-------------|
| `THE_MCCULLOUGHS_ORG_DATABASE_PASSWORD` | PostgreSQL password |
| `S3_ACCESS_KEY_ID` | S3-compatible storage key |
| `S3_SECRET_ACCESS_KEY` | S3-compatible storage secret |
| `S3_REGION` | S3 region (e.g., nyc3) |
| `S3_BUCKET` | S3 bucket name |
| `S3_ENDPOINT` | S3 endpoint URL |
| `REDIS_URL` | Redis URL (for Action Cable) |

## Default Credentials (Development)

- **Admin**: `admin@the-mcculloughs.org` / `password123`
- **Member 1**: `john@the-mcculloughs.org` / `password123`
- **Member 2**: `jane@the-mcculloughs.org` / `password123`
