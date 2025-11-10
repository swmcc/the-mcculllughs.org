# The McCulloughs Family Photo Sharing

A modern, mobile-first, private photo and video sharing application built with Rails 8 for family use.

## Features

- **User Authentication**: Secure sign-up and login with Devise
- **Role Management**: Admin and Member roles
- **Photo Galleries**: Create and organize family photo galleries
- **Media Upload**: Upload photos and videos with captions
- **Image Processing**: Automatic thumbnail generation for all uploads
- **Mobile-First Design**: Beautiful, responsive interface built with TailwindCSS
- **Real-time Updates**: Hotwire (Turbo + Stimulus) for smooth interactions
- **Private & Secure**: Family-only access, no public sharing
- **Background Jobs**: Solid Queue for async image processing (no Redis required)

## Tech Stack

- **Ruby**: 3.3.0
- **Rails**: 8.0.2
- **Database**: PostgreSQL
- **Authentication**: Devise
- **Styling**: TailwindCSS v4
- **JavaScript**: Hotwire (Turbo + Stimulus)
- **File Storage**: Active Storage with S3-compatible storage (DigitalOcean Spaces/MinIO)
- **Background Jobs**: Solid Queue (database-backed, no Redis)
- **Testing**: RSpec with Factory Bot
- **Image Processing**: ImageProcessing + MiniMagick

## Prerequisites

- Ruby 3.3.0 or higher
- PostgreSQL
- ImageMagick (for image processing)
- Node.js (for asset compilation)

### Install ImageMagick

**macOS:**
```bash
brew install imagemagick
```

**Ubuntu/Debian:**
```bash
sudo apt-get install imagemagick
```

## Setup Instructions

### 1. Clone and Install Dependencies

```bash
# Install Ruby gems
bundle install

# Install JavaScript dependencies (if needed)
# npm install or yarn install
```

### 2. Configure Environment Variables

Copy the example environment file and configure it:

```bash
cp .env.example .env
```

Edit `.env` and add your configuration:

```env
# Database
THE_MCCULLOUGHS_ORG_DATABASE_PASSWORD=your_db_password

# S3-Compatible Storage (DigitalOcean Spaces or MinIO)
S3_ACCESS_KEY_ID=your_access_key
S3_SECRET_ACCESS_KEY=your_secret_key
S3_REGION=nyc3
S3_BUCKET=the-mcculloughs-org
S3_ENDPOINT=https://nyc3.digitaloceanspaces.com

# Redis (for Action Cable - optional)
REDIS_URL=redis://localhost:6379/1

# Application
APP_HOST=localhost:3000
APP_URL=http://localhost:3000
```

### 3. Database Setup

```bash
# Create database
rails db:create

# Run migrations
rails db:migrate

# Seed initial data
rails db:seed
```

### 4. Start the Application

```bash
# Start Rails server and background jobs
bin/dev
```

The application will be available at `http://localhost:3000`

## Default User Accounts

After seeding, you can log in with these accounts:

- **Admin**: `admin@the-mcculloughs.org` / `password123`
- **Member 1**: `john@the-mcculloughs.org` / `password123`
- **Member 2**: `jane@the-mcculloughs.org` / `password123`

**⚠️ Important**: Change these passwords in production!

## Storage Configuration

### Local Development

By default, the app uses local disk storage. Update `config/environments/development.rb`:

```ruby
config.active_storage.service = :local
```

### Production (S3-Compatible)

For production, configure S3-compatible storage in `config/environments/production.rb`:

```ruby
config.active_storage.service = :spaces
```

Ensure your `.env` file has the correct S3 credentials.

## Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/user_spec.rb

# Run with coverage
COVERAGE=true bundle exec rspec
```

## Background Jobs

This application uses Solid Queue for background job processing (database-backed, no Redis required for basic operation).

Background jobs handle:
- Image thumbnail generation
- Video processing (placeholder for future implementation)

Jobs are automatically processed when you run `bin/dev`.

## Deployment

### Database Migration

```bash
rails db:migrate RAILS_ENV=production
```

### Asset Precompilation

```bash
rails assets:precompile RAILS_ENV=production
```

### Environment Variables

Ensure all production environment variables are set:
- Database credentials
- S3 storage credentials
- Application URL
- SMTP settings for emails

## Project Structure

```
app/
├── controllers/
│   ├── application_controller.rb
│   ├── galleries_controller.rb
│   └── uploads_controller.rb
├── models/
│   ├── user.rb              # Devise user with roles
│   ├── gallery.rb           # Photo gallery
│   └── upload.rb            # Media uploads
├── views/
│   ├── layouts/
│   │   └── application.html.erb
│   ├── galleries/
│   │   ├── index.html.erb
│   │   ├── show.html.erb
│   │   ├── new.html.erb
│   │   └── edit.html.erb
│   └── devise/              # Authentication views
├── jobs/
│   └── process_media_job.rb # Background image processing
└── assets/
    └── tailwind/
        └── application.css   # TailwindCSS styles

config/
├── database.yml             # PostgreSQL configuration
├── storage.yml              # Active Storage configuration
└── routes.rb                # Application routes

spec/                        # RSpec test files
```

## API & Routes

### Main Routes

- `GET /` - Galleries index (root)
- `GET /galleries` - List all galleries
- `GET /galleries/:id` - Show gallery with uploads
- `POST /galleries` - Create new gallery
- `PATCH/PUT /galleries/:id` - Update gallery
- `DELETE /galleries/:id` - Delete gallery
- `POST /galleries/:gallery_id/uploads` - Upload media to gallery
- `DELETE /uploads/:id` - Delete upload

### Admin Routes

- `GET /admin` - Admin dashboard
- `/admin/users` - User management
- `/admin/galleries` - Gallery management
- `/admin/uploads` - Upload management

## Customization

### Adding New Features

1. Generate a new model:
   ```bash
   rails generate model Feature name:string
   ```

2. Generate a controller:
   ```bash
   rails generate controller Features
   ```

3. Add routes to `config/routes.rb`

### Tailwind Customization

Edit `app/assets/tailwind/application.css` to customize styles.

Rebuild Tailwind:
```bash
rails tailwindcss:build
```

## Troubleshooting

### ImageMagick Not Found

If you get errors about ImageMagick:
```bash
# macOS
brew install imagemagick

# Verify installation
convert --version
```

### Database Connection Issues

Check your `config/database.yml` and ensure PostgreSQL is running:
```bash
# macOS
brew services start postgresql

# Ubuntu
sudo service postgresql start
```

### Asset Not Compiling

Rebuild assets:
```bash
rails assets:clobber
rails assets:precompile
```

## Contributing

This is a private family application. If you're a family member and want to suggest features, please reach out!

## License

Private - Family Use Only

## Support

For issues or questions, please contact the administrator.
