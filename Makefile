APP_NAME=the-mcculloughs-org
RAILS_ENV ?= development

GREEN := $(shell tput -Txterm setaf 2)
RESET := $(shell tput -Txterm sgr0)

.DEFAULT_GOAL := help

# -----------------------------
# 🧩 Local Development
# -----------------------------

local.run: ## Run the Rails app (with bin/dev)
	@echo "$(GREEN)==> Running $(APP_NAME) in $(RAILS_ENV)...$(RESET)"
	bin/dev

local.setup: ## Install gems, setup db, seed
	@echo "$(GREEN)==> Setting up $(APP_NAME)...$(RESET)"
	bundle install
	bin/rails db:create
	bin/rails db:migrate
	bin/rails db:seed
	@echo "$(GREEN)==> Setup complete! Run 'make local.run' to start$(RESET)"

local.install: ## Just install dependencies
	bundle install

local.db.create: ## Create the database
	bin/rails db:create

local.db.drop: ## Drop the database
	bin/rails db:drop

local.db.migrate: ## Run database migrations
	bin/rails db:migrate

local.db.seed: ## Seed the database
	bin/rails db:seed

local.db.reset: ## Reset the database (drop, create, migrate, seed)
	bin/rails db:reset

local.db.rollback: ## Rollback last migration
	bin/rails db:rollback

local.db.status: ## Check migration status
	bin/rails db:migrate:status

local.test: ## Run RSpec tests
	bundle exec rspec

local.test.fast: ## Run RSpec tests without coverage
	COVERAGE=false bundle exec rspec

local.test.models: ## Run model tests only
	bundle exec rspec spec/models

local.test.requests: ## Run request tests only
	bundle exec rspec spec/requests

local.test.jobs: ## Run job tests only
	bundle exec rspec spec/jobs

console: ## Start Rails console
	bin/rails console

routes: ## Show all routes
	bin/rails routes

routes.grep: ## Search routes (usage: make routes.grep GREP=galleries)
	bin/rails routes | grep $(GREP)

# -----------------------------
# 🎨 Assets & Styling
# -----------------------------

assets.build: ## Compile all assets
	bin/rails assets:precompile

assets.clean: ## Clean compiled assets
	bin/rails assets:clobber

tailwind.build: ## Build Tailwind CSS once
	bin/rails tailwindcss:build

tailwind.watch: ## Watch and rebuild Tailwind CSS on changes
	bin/rails tailwindcss:watch

# -----------------------------
# ✅ Code Quality & Security
# -----------------------------

lint: ## Run RuboCop linting
	bundle exec rubocop

lint.fix: ## Auto-fix RuboCop issues
	bundle exec rubocop -A

local.brakeman: ## Run Brakeman static security analysis
	bin/brakeman --exit-on-warn --no-pager

local.audit: ## Check for vulnerable dependencies
	bundle audit check --update

# -----------------------------
# 📦 Background Jobs
# -----------------------------

jobs.start: ## Start Solid Queue job processor
	bin/jobs

jobs.status: ## Show job queue status
	bin/rails runner "puts 'Jobs in queue: ' + SolidQueue::Job.count.to_s"

# -----------------------------
# 📊 Logs & Monitoring
# -----------------------------

logs: ## Tail development logs
	tail -f log/development.log

logs.clear: ## Clear all log files
	rm -f log/*.log

# -----------------------------
# 🧹 Cleanup
# -----------------------------

clean: ## Clean temporary files, logs, and cached assets
	@echo "$(GREEN)==> Cleaning temporary files...$(RESET)"
	rm -rf tmp/cache/* tmp/pids/* tmp/sockets/* tmp/storage/*
	rm -rf log/*.log
	rm -rf public/assets
	rm -rf app/assets/builds/*
	@echo "$(GREEN)==> Cleanup complete$(RESET)"

# -----------------------------
# 💾 Backup & Restore
# -----------------------------

local.db.pull: ## Pull production database via SSH tunnel (requires Docker)
	@echo "$(GREEN)==> Pulling production database...$(RESET)"
	@bash -c 'set -a; source .env.production; set +a; \
		echo "$(GREEN)==> Opening SSH tunnel to $$PROD_SSH_HOST...$(RESET)"; \
		ssh -f -N -L 5433:$$PROD_DB_HOST:$$PROD_DB_PORT $$PROD_SSH_USER@$$PROD_SSH_HOST && \
		sleep 2 && \
		echo "$(GREEN)==> Dumping production database...$(RESET)" && \
		docker run --rm -v /tmp:/tmp -e PGPASSWORD=$$PROD_DB_PASSWORD postgres:17-alpine \
			pg_dump -h host.docker.internal -p 5433 -U $$PROD_DB_USER -Fc $$PROD_DB_NAME -f /tmp/prod_dump.dump && \
		echo "$(GREEN)==> Restoring to local database...$(RESET)" && \
		bin/rails db:drop db:create && \
		docker run --rm -v /tmp:/tmp postgres:17-alpine \
			pg_restore --verbose --clean --no-acl --no-owner -h host.docker.internal -U $(USER) -d the_mcculloughs_org_development /tmp/prod_dump.dump; \
		rm -f /tmp/prod_dump.dump; \
		pkill -f "ssh.*5433.*$$PROD_SSH_HOST" || true; \
		echo "$(GREEN)==> Production database pulled successfully$(RESET)"'

local.db.pull.dump-only: ## Just dump production DB (no restore)
	@echo "$(GREEN)==> Dumping production database...$(RESET)"
	@mkdir -p db/backups
	@bash -c 'set -a; source .env.production; set +a; \
		ssh -f -N -L 5433:$$PROD_DB_HOST:$$PROD_DB_PORT $$PROD_SSH_USER@$$PROD_SSH_HOST && \
		sleep 2 && \
		docker run --rm -v $(PWD)/db/backups:/backups -e PGPASSWORD=$$PROD_DB_PASSWORD postgres:17-alpine \
			pg_dump -h host.docker.internal -p 5433 -U $$PROD_DB_USER -Fc $$PROD_DB_NAME -f /backups/prod_$$(date +%Y%m%d_%H%M%S).dump && \
		pkill -f "ssh.*5433.*$$PROD_SSH_HOST" || true && \
		echo "$(GREEN)==> Dump saved to db/backups/$(RESET)"'

local.storage.pull: ## Sync S3 images to local storage (downloads by blob key)
	@echo "$(GREEN)==> Downloading S3 images to local storage...$(RESET)"
	@bash -c 'set -a; source .env.production; set +a; bin/rails storage:pull_from_s3'
	@echo "$(GREEN)==> Storage sync complete$(RESET)"

local.pull: local.db.pull local.storage.pull ## Pull both database and storage from production

backup.db: ## Backup database to db/backups/
	@mkdir -p db/backups
	@echo "$(GREEN)==> Backing up database...$(RESET)"
	pg_dump the_mcculloughs_org_development > db/backups/backup_$$(date +%Y%m%d_%H%M%S).sql
	@echo "$(GREEN)==> Database backed up$(RESET)"

restore.db: ## Restore database from backup (requires BACKUP_FILE=path/to/backup.sql)
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo "Usage: make restore.db BACKUP_FILE=db/backups/backup_YYYYMMDD_HHMMSS.sql"; \
		exit 1; \
	fi
	@echo "$(GREEN)==> Restoring database from $(BACKUP_FILE)...$(RESET)"
	bin/rails db:drop db:create
	psql the_mcculloughs_org_development < $(BACKUP_FILE)
	@echo "$(GREEN)==> Database restored$(RESET)"

# -----------------------------
# 🚀 Production & Deployment
# -----------------------------

production.setup: ## Setup production environment
	@echo "$(GREEN)==> Setting up production environment...$(RESET)"
	RAILS_ENV=production bin/rails db:migrate
	RAILS_ENV=production bin/rails assets:precompile
	@echo "$(GREEN)==> Production setup complete$(RESET)"

production.console: ## Open Rails console in production mode
	RAILS_ENV=production bin/rails console

deploy.check: lint local.brakeman local.test ## Run all checks before deployment
	@echo "$(GREEN)==> All checks passed - ready for deployment!$(RESET)"

credentials.edit: ## Edit Rails credentials
	EDITOR=vim bin/rails credentials:edit

secret: ## Generate a new secret key
	bin/rails secret

# -----------------------------
# 🔧 Quick Actions
# -----------------------------

reset: clean local.db.reset ## Full reset (clean + database reset)
	@echo "$(GREEN)==> Full reset complete$(RESET)"

fresh: reset local.run ## Fresh start (reset + start server)

update: ## Update dependencies and database
	@echo "$(GREEN)==> Updating application...$(RESET)"
	git pull
	bundle install
	bin/rails db:migrate
	@echo "$(GREEN)==> Update complete$(RESET)"

# -----------------------------
# 🧰 Meta
# -----------------------------

help: ## Show all available make targets
	@echo "$(GREEN)Available targets:$(RESET)"
	@grep -E '^[a-zA-Z0-9_.-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  %-25s %s\n", $$1, $$2}'
