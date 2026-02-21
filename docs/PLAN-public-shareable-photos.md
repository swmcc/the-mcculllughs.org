# Plan: Public Shareable Photos

## Overview
Add ability to make individual photos public with a unique shareable link.

## Database Changes

### Migration: AddShareableFieldsToUploads
```ruby
add_column :uploads, :short_code, :string
add_column :uploads, :is_public, :boolean, default: false, null: false
add_index :uploads, :short_code, unique: true
```

## Model Changes

### Upload Model
```ruby
# Callbacks
before_validation :generate_short_code, on: :create

# Validations
validates :short_code, presence: true, uniqueness: true

# Scopes
scope :publicly_visible, -> { where(is_public: true) }

private

def generate_short_code
  return if short_code.present?

  loop do
    self.short_code = SecureRandom.alphanumeric(6)
    break unless Upload.exists?(short_code: short_code)
  end
end
```

## Routes

```ruby
# Public photo access (no auth required)
get "p/:short_code", to: "public_photos#show", as: :public_photo
```

URL format: `https://the-mcculloughs.org/p/Abc123`

## Controller

### PublicPhotosController
```ruby
class PublicPhotosController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @upload = Upload.find_by!(short_code: params[:short_code])

    unless @upload.is_public?
      raise ActiveRecord::RecordNotFound
    end
  end
end
```

## Views

### public_photos/show.html.erb
- Full-screen photo view
- Title, caption, date taken
- Download button
- Link back to main site
- Social media meta tags (og:image, etc.)

## Lightbox UI Changes

Add to bottom bar (for owners/admins):
- Toggle switch: "Public" / "Private"
- When public: Show copy link button with short URL
- Auto-save on toggle (like other fields)

## API Changes

### UploadsController#update
Add `is_public` to permitted params.

## Files to Create/Modify

1. `db/migrate/xxx_add_shareable_fields_to_uploads.rb` - New
2. `app/models/upload.rb` - Add short_code generation
3. `config/routes.rb` - Add public route
4. `app/controllers/public_photos_controller.rb` - New
5. `app/views/public_photos/show.html.erb` - New
6. `app/views/galleries/show.html.erb` - Add public toggle UI
7. `app/javascript/controllers/lightbox_controller.js` - Handle public toggle
8. `app/controllers/uploads_controller.rb` - Permit is_public

## Security Considerations

- Short code is 6 alphanumeric chars (~2.2 trillion combinations)
- Only `is_public: true` photos are accessible via public route
- No enumeration possible (random codes, not sequential)
- Gallery/user info not exposed on public view
