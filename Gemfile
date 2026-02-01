source "https://rubygems.org"

gem "aws-sdk-s3", require: false
gem "bootsnap", require: false
gem "devise"
gem "dotenv-rails"
gem "image_processing", "~> 1.2"
gem "importmap-rails"
gem "jbuilder"
gem "kamal", require: false
gem "pg", "~> 1.1"
gem "propshaft"
gem "puma", ">= 5.0"
gem "rails", "~> 8.1.2"
gem "redis", ">= 4.0.1"
gem "solid_cache"
gem "solid_queue"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "thruster", require: false
gem "turbo-rails"
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "brakeman", require: false
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "factory_bot_rails"
  gem "faker"
  gem "rspec-rails", "~> 8.0"
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "database_cleaner-active_record"
  gem "selenium-webdriver"
  gem "shoulda-matchers", "~> 7.0"
end
