source "https://rubygems.org"

# NOTE: the core framework. Everything else in this file is a library that solves
# a specific problem (database driver, password hashing, asset pipeline, web server).
# Per the project rule "DON'T INVENT ANYTHING, USE LIBRARIES FOR EVERYTHING" we do
# not hand-roll cryptography, SQL drivers or web servers.
gem "rails", "~> 8.1.4"

# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"

# PostgreSQL driver. PostgreSQL gives us a real UNIQUE INDEX that is enforced by
# the storage engine itself, which is what the task requires (uniqueness must not
# depend on application-level checks).
gem "pg", "~> 1.5"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"

# NOTE: `has_secure_password` (Active Model) needs bcrypt to hash passwords.
# We do NOT write our own hashing code - the library does it.
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache and Active Job
gem "solid_cache"
gem "solid_queue"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # NOTE: used by script/screenshot.rb - the visual check of the panel. The
  # script drives a real browser, signs in and stores the screenshots in
  # tmp/screenshots.
  gem "selenium-webdriver", "~> 4.20"
end
