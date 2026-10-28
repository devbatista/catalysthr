require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative "../lib/middleware/host_resolver"

module CatalystHr
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks middleware])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.eager_load_paths << Rails.root.join("extras")

    # Times are stored in UTC. The default display zone is Brasília; each unit
    # has its own zone for time entries and deadlines (RN-04-013, P-04-07).
    config.time_zone = "Brasilia"

    # UI in Brazilian Portuguese; code in English (spec 00).
    config.i18n.available_locales = [ :"pt-BR" ]
    config.i18n.default_locale = :"pt-BR"

    # Background jobs run on Sidekiq (D-108, spec 20).
    config.active_job.queue_adapter = :sidekiq

    # Hosts (spec 01, RN-01-001): the admin area and the brands' subdomains,
    # <slug>.<panel_domain>. Development overrides them with *.localhost.
    config.x.admin_host = ENV.fetch("ADMIN_HOST", "admin.catalysthr.com.br")
    config.x.panel_domain = ENV.fetch("PANEL_DOMAIN", "painel.catalysthr.com.br")
    # Protocol of the links sent by e-mail; HTTPS in production (force_ssl).
    config.x.panel_protocol = ENV.fetch("PANEL_PROTOCOL", Rails.env.production? ? "https" : "http")
    # Port of the links, only when it is not the protocol's default (development).
    config.x.public_port = ENV["PUBLIC_PORT"].presence
    # The SNS topic of the SES events (spec 15, P-15-24, D-609); the app accepts no other.
    config.x.ses_events_topic_arn = ENV.fetch("SES_EVENTS_TOPIC_ARN", "arn:aws:sns:sa-east-1:464986173446:catalysthr-ses-eventos")
    # Mercado Pago (spec 19, P-19-29, D-622): the account's access token and the webhook's
    # secret signature, from Suas integrações. Without the token, no PIX is generated.
    config.x.mercado_pago_access_token = ENV["MERCADO_PAGO_ACCESS_TOKEN"].presence
    config.x.mercado_pago_webhook_secret = ENV["MERCADO_PAGO_WEBHOOK_SECRET"].presence
    # Asaas, only for the NFS-e (spec 19, D-633): the API key, whose prefix says sandbox or
    # production. Without it, no note is issued.
    config.x.asaas_api_key = ENV["ASAAS_API_KEY"].presence
    config.middleware.use HostResolver
    # Files are only served by the application's own controllers, after checking who
    # asks (RN-01-014, P-01-09). Active Storage's public blob routes stay off.
    config.active_storage.draw_routes = false

    # Request limits per IP (RN-02-032, config/initializers/rack_attack.rb).
    config.middleware.use Rack::Attack

    # Field encryption (D-086, P-05-02, P-05-03). Keys come from Railway variables,
    # never from the repository; development and tests set local keys. A missing key
    # makes every read and write of an encrypted field raise, so nothing is stored in
    # plain text. Losing the keys makes the encrypted fields unreadable: keep a copy
    # outside Railway.
    config.active_record.encryption.primary_key = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
    config.active_record.encryption.deterministic_key = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]
    config.active_record.encryption.key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]

    config.generators do |g|
      # Every table has a UUIDv7 primary key (D-614).
      g.orm :active_record, primary_key_type: :uuid
      g.test_framework :rspec, fixtures: true, view_specs: false, helper_specs: false, routing_specs: false
      g.fixture_replacement :factory_bot, dir: "spec/factories"
      g.system_tests = nil
    end
  end
end
