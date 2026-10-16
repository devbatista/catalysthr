# Feature flags (spec 20, P-20-11). Every new feature starts disabled and is turned on
# in Flipper. Declared here so tests and development know them (config/initializers/flipper.rb).
module FeatureFlags
  # Sign-in, recovery and unlock (spec 02). Off until the release in production.
  SIGN_IN = :sign_in
  # The brand's e-mail domain in SES (spec 01, RN-01-040, D-596).
  BRAND_EMAIL_DOMAIN = :brand_email_domain

  ALL = [ SIGN_IN, BRAND_EMAIL_DOMAIN ].freeze

  module_function

  def enabled?(name, actor = nil)
    Flipper.enabled?(name, actor)
  end

  # Creates the declared flags, disabled. Idempotent. Strict mode would refuse to
  # add a flag that does not exist yet, so this runs in its sync mode.
  def declare
    Flipper::Adapters::Strict.with_sync_mode { ALL.each { |name| Flipper.add(name) } }
  end
end
