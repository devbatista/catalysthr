require "rails_helper"

# Guards the Sentry initializer: an unknown option would only fail in
# production, where SENTRY_DSN is set (D-506, D-510).
RSpec.describe "Sentry initializer" do
  around do |example|
    original = ENV["SENTRY_DSN"]
    ENV["SENTRY_DSN"] = "https://public@o0.ingest.us.sentry.io/0"
    example.run
  ensure
    Sentry.close if Sentry.initialized?
    ENV["SENTRY_DSN"] = original
  end

  it "boots without errors, forwards logs and never sends personal data" do
    expect { load Rails.root.join("config/initializers/sentry.rb") }.not_to raise_error

    expect(Sentry).to be_initialized
    expect(Sentry.configuration.enabled_patches).to include(:logger)
    expect(Sentry.configuration.send_default_pii).to be(false)
  end

  it "masks personal data in log bodies" do
    load Rails.root.join("config/initializers/sentry.rb")
    log = Sentry::LogEvent.new(level: :info, body: "CPF 123.456.789-09 de ana@empresa.com.br")

    result = Sentry.configuration.before_send_log.call(log)

    expect(result.body).to eq("CPF [cpf] de [email]")
  end
end
