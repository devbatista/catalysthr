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
    config.middleware.use HostResolver

    config.generators do |g|
      g.test_framework :rspec, fixtures: true, view_specs: false, helper_specs: false, routing_specs: false
      g.fixture_replacement :factory_bot, dir: "spec/factories"
      g.system_tests = nil
    end
  end
end
