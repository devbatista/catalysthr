# The catalog of notices (spec 15, RN-15-010 to RN-15-013, P-15-05, P-15-07). It lives
# in the code and has only the types the system already sends; each spec adds its own
# when it is built (D-607). Channels: "system" is the bell, "email", "whatsapp" and
# "push" are external. A type without "system" stays out of the bell (D-608). Texts are
# in config/locales, under notification_types, and never carry sensitive data (RN-15-005).
NotificationType = Data.define(:code, :mandatory, :urgent, :channels) do
  def self.find(code) = self::CATALOG.fetch(code.to_s)

  def self.all = self::CATALOG.values

  def in_bell? = channels.include?("system")

  def external_channels = channels - %w[system]
end

NotificationType::CATALOG = [
  # The person. The unlock e-mail is already an access notice (RN-15-011), so the lockout
  # goes to the bell only in phase 1 (D-607). WhatsApp comes in phase 2.
  NotificationType.new(code: "security.account_locked", mandatory: true, urgent: false, channels: %w[system]),
  NotificationType.new(code: "security.mfa_reset", mandatory: true, urgent: false, channels: %w[system email]),
  # To the new e-mail; the old one is told directly, since it belongs to no one (D-607).
  NotificationType.new(code: "security.contact_changed", mandatory: true, urgent: false, channels: %w[email]),
  # The partner's administrator, the direct company's HR administrator or whoever
  # registered the domain (RN-01-040).
  NotificationType.new(code: "brand.email_domain_status", mandatory: true, urgent: false, channels: %w[system email]),
  # The HR, within each person's scope (P-04-29, D-608).
  NotificationType.new(code: "employments.revisions_effective", mandatory: false, urgent: false, channels: %w[system email])
].index_by(&:code).freeze
