# The McCulloughs - AI Agent Instructions

## Quick Reference Commands

| Task | Command |
|------|---------|
| Run all tests | `make local.test` |
| Run tests (fast) | `make local.test.fast` |
| Lint code | `make lint` |
| Fix lint issues | `make lint.fix` |
| Security scan | `make local.brakeman` |
| Start server | `make local.run` or `bin/dev` |
| Database migrate | `make local.db.migrate` |
| Database reset | `make local.db.reset` |
| Rails console | `make console` |
| Pre-deploy check | `make deploy.check` |

## Key Files

| Purpose | File |
|---------|------|
| Routes | `config/routes.rb` |
| Database schema | `db/schema.rb` |
| User model | `app/models/user.rb` |
| Gallery model | `app/models/gallery.rb` |
| Upload model | `app/models/upload.rb` |
| Main controller | `app/controllers/application_controller.rb` |
| Galleries controller | `app/controllers/galleries_controller.rb` |
| Uploads controller | `app/controllers/uploads_controller.rb` |
| Media processing job | `app/jobs/process_media_job.rb` |
| Dropzone controller | `app/javascript/controllers/dropzone_controller.js` |
| Devise config | `config/initializers/devise.rb` |
| Storage config | `config/storage.yml` |
| User factory | `spec/factories/users.rb` |
| Gallery factory | `spec/factories/galleries.rb` |
| Upload factory | `spec/factories/uploads.rb` |

## Implementation Guidelines

### Before Making Changes

1. **Read the spec**: Check `openspec/specs/` for domain requirements
2. **Run tests**: `make local.test` to establish baseline
3. **Check lint**: `make lint` to verify code style

### When Adding Features

1. **Start with the model**: Define associations, validations, scopes
2. **Add migration**: `bin/rails generate migration AddFieldToModel field:type`
3. **Update routes**: Add to `config/routes.rb`
4. **Create controller**: Follow RESTful conventions
5. **Add views**: Use TailwindCSS, support Turbo Stream
6. **Write tests**: Model specs, request specs
7. **Run full check**: `make deploy.check`

### Model Changes

```ruby
# Always include:
# - Associations with dependent: :destroy where appropriate
# - Presence validations for required fields
# - Scopes for common queries
# - Enums for fixed-value fields
```

### Controller Patterns

```ruby
# Standard CRUD controller structure:
class ThingsController < ApplicationController
  before_action :set_thing, only: [:show, :edit, :update, :destroy]

  def index
    @things = Thing.recent
  end

  def show
  end

  def new
    @thing = Thing.new
  end

  def create
    @thing = current_user.things.build(thing_params)
    respond_to do |format|
      if @thing.save
        format.html { redirect_to @thing, notice: "Thing created." }
        format.turbo_stream
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # ... edit, update, destroy

  private

  def set_thing
    @thing = Thing.find(params[:id])
  end

  def thing_params
    params.require(:thing).permit(:allowed, :fields)
  end
end
```

### Testing Patterns

```ruby
# Model spec
RSpec.describe Thing, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should have_many(:items).dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:name) }
  end
end

# Request spec
RSpec.describe "Things", type: :request do
  let(:user) { create(:user) }
  before { sign_in user }

  describe "GET /things" do
    it "returns http success" do
      get things_path
      expect(response).to have_http_status(:success)
    end
  end
end
```

### Adding Stimulus Controllers

1. Create controller in `app/javascript/controllers/`
2. Name file `[name]_controller.js`
3. Register in `app/javascript/controllers/index.js`
4. Use in HTML: `data-controller="name"`

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["element"]
  static values = { config: String }

  connect() {
    // Initialize
  }

  action(event) {
    // Handle action
  }
}
```

## Common Tasks

### Add a New Model

```bash
# Generate model with migration
bin/rails generate model Thing name:string user:references

# Edit migration if needed
# Edit model to add validations, associations, scopes

# Run migration
make local.db.migrate

# Add factory
# spec/factories/things.rb

# Add tests
# spec/models/thing_spec.rb
```

### Add File Attachment

```ruby
# In model
class Thing < ApplicationRecord
  has_one_attached :image
  # or
  has_many_attached :images
end

# In controller params
def thing_params
  params.require(:thing).permit(:name, :image)
  # or for multiple
  params.require(:thing).permit(:name, images: [])
end
```

### Add Background Job

```ruby
# Generate job
bin/rails generate job ProcessThing

# Implement in app/jobs/process_thing_job.rb
class ProcessThingJob < ApplicationJob
  queue_as :default

  def perform(thing_id)
    thing = Thing.find(thing_id)
    # Process...
  end
end

# Trigger from model callback
after_commit :process_async, on: :create

private

def process_async
  ProcessThingJob.perform_later(id)
end
```

### Add Admin Feature

```ruby
# In controller requiring admin access
before_action :require_admin!

# require_admin! is defined in ApplicationController
def require_admin!
  redirect_to root_path, alert: "Access denied." unless current_user&.admin?
end
```

## Debugging

### Check Logs

```bash
# Tail development logs
make logs

# Or directly
tail -f log/development.log
```

### Rails Console

```bash
make console

# Common debugging
User.all
Gallery.includes(:uploads).find(1)
Upload.where(gallery_id: 1).count
```

### Check Routes

```bash
make routes

# Search for specific route
make routes.grep GREP=galleries
```

## Pre-Commit Checklist

1. [ ] Tests pass: `make local.test`
2. [ ] Lint passes: `make lint`
3. [ ] Security scan passes: `make local.brakeman`
4. [ ] Commit message uses gitmoji format
5. [ ] No secrets in committed files
