# Feature flags (spec 20, P-20-11). Every new feature starts disabled and is turned on
# in Flipper. Declared here so tests and development know them (config/initializers/flipper.rb).
module FeatureFlags
  # Sign-in, recovery and unlock (spec 02). Off until the release in production.
  SIGN_IN = :sign_in
  # The brand's e-mail domain in SES (spec 01, RN-01-040, D-596).
  BRAND_EMAIL_DOMAIN = :brand_email_domain
  # Company transfer by the superadmin (spec 01, RN-01-050 to RN-01-053, D-599).
  COMPANY_TRANSFER = :company_transfer
  # Plans, contracts, usage, invoices and payments (spec 19), off until the launch (D-610).
  BILLING = :billing
  # The NFS-e through Asaas (spec 19, section 4.11, D-633), on its own so the billing can
  # launch before the notes are ready.
  NFSE = :nfse
  # Passkeys (spec 16, section 4.8, D-645). Off, nobody sees the option; the reset of the MFA
  # removes the ones already registered either way (RN-16-076).
  PASSKEYS = :passkeys

  # The admissions (spec 07, D-648). While off, the menu keeps "Em breve".
  ADMISSIONS = :admissions

  ALL = [ SIGN_IN, BRAND_EMAIL_DOMAIN, COMPANY_TRANSFER, BILLING, NFSE, PASSKEYS, ADMISSIONS ].freeze
  # Flags the admin's screen never turns off: without sign-in, every page answers 404,
  # the screen included, and only the console turns it on again (D-617).
  NOT_OFF_ON_SCREEN = [ SIGN_IN ].freeze

  module_function

  def enabled?(name, actor = nil)
    Flipper.enabled?(name, actor)
  end

  # Creates the declared flags, disabled. Idempotent. Strict mode would refuse to
  # add a flag that does not exist yet, so this runs in its sync mode.
  def declare
    Flipper::Adapters::Strict.with_sync_mode { ALL.each { |name| Flipper.add(name) } }
  end

  # The admin's screen (D-617). A flag is born with the code that checks it, so the screen
  # never invents one: it shows the declared flags, the ones still missing in the
  # database and the ones the code no longer declares.
  def find(name)
    ALL.find { |flag| flag.to_s == name.to_s }
  end

  def stored
    Flipper.features.map { |feature| feature.key.to_sym }
  end

  def missing
    ALL - stored
  end

  def undeclared
    stored - ALL
  end

  # :on, :off, :conditional (on for some actors only) or :missing.
  def state(name)
    stored.include?(name) ? Flipper[name].state : :missing
  end

  # Turns a declared flag on or off for everyone, recording who did it. Turning off also
  # clears any actor the flag was on for.
  def switch!(name, on:, by:)
    raise ArgumentError, "#{name} is turned off only through the console" if !on && NOT_OFF_ON_SCREEN.include?(name)

    ActiveRecord::Base.transaction do
      on ? Flipper.enable(name) : Flipper.disable(name)
      FeatureFlagChange.create!(flag: name, action: on ? "enabled" : "disabled", changed_by: by)
    end
  end

  # Creates the declared flags the database lacks, disabled.
  def declare_missing!(by:)
    names = missing
    ActiveRecord::Base.transaction do
      declare
      names.each { |name| FeatureFlagChange.create!(flag: name, action: "declared", changed_by: by) }
    end
    names
  end

  # Removes a flag the code no longer declares; a declared one is never removed.
  def remove_undeclared!(name, by:)
    flag = undeclared.find { |stored_flag| stored_flag.to_s == name.to_s }
    return if flag.nil?

    ActiveRecord::Base.transaction do
      Flipper.remove(flag)
      FeatureFlagChange.create!(flag: flag, action: "removed", changed_by: by)
    end
    flag
  end
end
