# The catalog of notices (spec 15, RN-15-010 to RN-15-013, P-15-05, P-15-07). It lives
# in the code and has only the types the system already sends; each spec adds its own
# when it is built (D-607). Channels: "system" is the bell, "email", "whatsapp" and
# "push" are external. A type without "system" stays out of the bell (D-608). Texts are
# in config/locales, under notification_types, and never carry sensitive data (RN-15-005).
# roles: who gets the type, which decides where its channels can be chosen; :all is
# everyone.
NotificationType = Data.define(:code, :mandatory, :urgent, :channels, :roles) do
  def self.find(code) = self::CATALOG.fetch(code.to_s)

  def self.all = self::CATALOG.values

  # The types a person with these roles can configure: those with a channel to choose.
  def self.configurable_for(roles)
    all.select { |type| type.configurable_channels.any? && (type.roles == :all || type.roles.intersect?(roles)) }
  end

  def in_bell? = channels.include?("system")

  def external_channels = channels - %w[system]

  def configurable_channels = external_channels & self.class::AVAILABLE_CHANNELS
end

# External channels that exist in this phase; WhatsApp and push come in phase 2 (D-607).
NotificationType::AVAILABLE_CHANNELS = %w[email].freeze

NotificationType::CATALOG = [
  # The person. The unlock e-mail is already an access notice (RN-15-011), so the lockout
  # goes to the bell only in phase 1 (D-607). WhatsApp comes in phase 2.
  NotificationType.new(code: "security.account_locked", mandatory: true, urgent: false, channels: %w[system], roles: :all),
  NotificationType.new(code: "security.mfa_reset", mandatory: true, urgent: false, channels: %w[system email], roles: :all),
  # To the new e-mail; the old one is told directly, since it belongs to no one (D-607).
  NotificationType.new(code: "security.contact_changed", mandatory: true, urgent: false, channels: %w[email], roles: :all),
  # The partner's administrator or whoever registered the domain (RN-01-040).
  NotificationType.new(code: "brand.email_domain_status", mandatory: true, urgent: false, channels: %w[system email],
    roles: %w[partner_admin]),
  # The HR, within each person's scope (P-04-29, D-608).
  NotificationType.new(code: "employments.revisions_effective", mandatory: false, urgent: false, channels: %w[system email],
    roles: %w[hr_admin hr_analyst consultant]),
  # Someone's e-mail bounced, to the HR of the scope (RN-15-083, D-609).
  NotificationType.new(code: "contacts.email_invalid", mandatory: false, urgent: false, channels: %w[system email],
    roles: %w[hr_admin hr_analyst partner_admin firm_admin]),
  # The trial, to the contract's responsible: the partner's administrator or the direct
  # company's HR administrator (RN-19-032, RN-19-034, D-616).
  NotificationType.new(code: "billing.trial_ending", mandatory: true, urgent: false, channels: %w[system email],
    roles: %w[partner_admin hr_admin]),
  NotificationType.new(code: "billing.trial_expired", mandatory: true, urgent: false, channels: %w[system email],
    roles: %w[partner_admin hr_admin])
].index_by(&:code).freeze
