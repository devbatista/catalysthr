source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.4"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 2.2"
# image_processing 2 no longer brings it; Active Storage analyzes uploaded images with it.
# Loaded on demand, as before, so booting does not need libvips (the CI runner has none).
gem "ruby-vips", "~> 2.3", require: false

# PDFs (stack, spec 08): a document's images joined in one PDF (RN-08-011)
gem "prawn", "~> 2.5"

# Imports (spec 18, P-18-25): roo reads the XLSX sent, caxlsx writes the templates and the
# errors' spreadsheet. roo 3, a year old, instead of the 4 of weeks ago, with the same needs.
gem "roo", "~> 4.0"
gem "caxlsx", "~> 4.5"

# Background jobs and schedules (D-108, spec 20)
gem "sidekiq"
gem "sidekiq-cron"

# Rails cache in Postgres; Redis is reserved for Sidekiq (D-511)
gem "solid_cache"

# Safe, backward-compatible migrations (P-20-11)
gem "strong_migrations"

# Company isolation: every company-owned model is scoped to the current tenant (D-150, P-01-05)
gem "acts_as_tenant", "~> 2.2"

# Feature flags stored in Postgres (P-20-11)
gem "flipper", "~> 1.4"
gem "flipper-active_record", "~> 1.4"

# Observability: errors, performance and JSON logs (D-506, D-510)
gem "sentry-ruby"
gem "sentry-rails"
gem "sentry-sidekiq"
gem "lograge"

# Portuguese translations for Rails
gem "rails-i18n"

# Sign-in by CPF or e-mail, password recovery and lockout (spec 02, P-02-35)
gem "devise", "~> 5.0"

# MFA with an authenticator app (TOTP) and recovery codes (RN-02-042, P-02-35)
gem "devise-two-factor", "~> 6.4"
# Passkeys: the WebAuthn ceremonies (spec 16, RN-16-070, P-16-26)
gem "webauthn", "~> 3.5"

# QR code of the authenticator setup, drawn as SVG on the server (RN-02-042)
gem "rqrcode", "~> 3.1"

# Permissions as the sum of partial abilities (spec 03, P-03-08)
gem "cancancan", "~> 3.7"

# Change trail without sensitive fields (spec 05, RN-05-010, D-084)
gem "paper_trail", "~> 17.0"

# Request limits per IP against attempts on many CPFs (RN-02-032, P-02-15)
gem "rack-attack", "~> 6.8"

# Support sees the system as a user, read only with simulated writes (RN-02-080, P-02-37)
gem "pretender", "~> 1.0"

# Files on S3 in São Paulo, encrypted with SSE-KMS by the bucket (spec 20, RN-01-014, D-595)
gem "aws-sdk-s3", "~> 1.237", require: false

# E-mail through SES in São Paulo, and the brands' e-mail domains (spec 15, RN-01-040, D-596)
gem "aws-actionmailer-ses", "~> 1.2"
gem "aws-sdk-sesv2", "~> 1.117"

# The signature of the SES events that SNS posts to the app (spec 15, P-15-24, D-609)
gem "aws-sdk-sns", "~> 1.126"

# The employer's A1 certificate, sealed with its own KMS key in São Paulo (spec 13, D-075, RN-20-052)
gem "aws-sdk-kms", "~> 1.138", require: false

# The official Claude SDK, with structured outputs and prompt caching, only with the
# features under zero data retention: no Batch API, no Files API (spec 14, P-14-39, D-385)
gem "anthropic", "~> 2.3.0"

# The partner's usage report (spec 19, RN-19-024). Out of the default gems since Ruby 3.4.
gem "csv", "~> 3.3"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Tests (D-027, P-14-35)
  gem "rspec-rails"
  gem "factory_bot_rails"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # No real external API calls in tests (P-14-35)
  gem "webmock"
  gem "simplecov", require: false
end

gem "web-push", "~> 3.1"
