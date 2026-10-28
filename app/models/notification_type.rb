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
    roles: %w[partner_admin hr_admin]),
  # 80% and 100% of the band of employees, to the contract's responsible (RN-19-022,
  # D-092). Specs 14 and 15 add the AI and WhatsApp quotas as other variants (D-101, D-407).
  NotificationType.new(code: "billing.usage_threshold", mandatory: true, urgent: false, channels: %w[system email],
    roles: %w[partner_admin hr_admin]),
  # The cycle's invoice, to the contract's responsible (RN-19-041, D-619).
  NotificationType.new(code: "billing.invoice_issued", mandatory: true, urgent: false, channels: %w[system email],
    roles: %w[partner_admin hr_admin]),
  # The 30 days' notice of a price migration, to the contract's responsible (RN-19-014, D-620).
  NotificationType.new(code: "billing.price_change", mandatory: true, urgent: false, channels: %w[system email],
    roles: %w[partner_admin hr_admin]),
  # The dunning, to the contract's responsible: the invoice past due on days 1, 5 and 10, and
  # the read only on day 15; the closing on days 25 and 30 (RN-19-050, D-116, D-493, D-624).
  NotificationType.new(code: "billing.overdue", mandatory: true, urgent: false, channels: %w[system email],
    roles: %w[partner_admin hr_admin]),
  NotificationType.new(code: "billing.contract_closing", mandatory: true, urgent: false, channels: %w[system email],
    roles: %w[partner_admin hr_admin]),
  # The partner's read only, to the HR administrator of each company of the portfolio,
  # without amounts (RN-19-052, D-495).
  NotificationType.new(code: "billing.partner_read_only", mandatory: true, urgent: false, channels: %w[system email],
    roles: %w[hr_admin]),
  # The cancellation asked by the client, to the responsible; and to the HR administrator of
  # each company of a partner's portfolio, 30 days before the end (RN-19-062, RN-19-063, D-625).
  NotificationType.new(code: "billing.cancel_scheduled", mandatory: true, urgent: false, channels: %w[system email],
    roles: %w[partner_admin hr_admin]),
  NotificationType.new(code: "billing.partner_cancelled", mandatory: true, urgent: false, channels: %w[system email],
    roles: %w[hr_admin]),
  # The CatalystHR team: an adjustment above 20% waiting for the superadmin (RN-19-071, D-621).
  NotificationType.new(code: "platform.adjustment_pending", mandatory: true, urgent: false, channels: %w[system email],
    roles: %w[superadmin]),
  # The CatalystHR team: an NFS-e refused, to the finance team and the superadmins
  # (RN-19-108, P-19-38, D-633).
  NotificationType.new(code: "platform.nfse_error", mandatory: true, urgent: false, channels: %w[system email],
    roles: %w[superadmin finance]),
  # The quarterly restore drill, to the superadmins (RN-20-046, D-627).
  NotificationType.new(code: "platform.restore_drill_due", mandatory: true, urgent: false, channels: %w[system email],
    roles: %w[superadmin])
].index_by(&:code).freeze
