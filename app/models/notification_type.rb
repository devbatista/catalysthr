# The catalog of notices (spec 15, RN-15-010 to RN-15-013, P-15-05, P-15-07). It lives
# in the code and has only the types the system already sends; each spec adds its own
# when it is built (D-607). Channels: "system" is the bell, "email", "whatsapp" and
# "push" are external. A type without "system" stays out of the bell (D-608). Texts are
# in config/locales, under notification_types, and never carry sensitive data (RN-15-005).
# roles: who gets the type, which decides where its channels can be chosen; :all is
# everyone. push_roles: for a type whose push is only some roles' in the catalog, those
# roles; nil is everyone who gets the type.
NotificationType = Data.define(:code, :mandatory, :urgent, :channels, :roles, :push_roles) do
  def initialize(push_roles: nil, **fields) = super(push_roles: push_roles, **fields)

  def self.find(code) = self::CATALOG.fetch(code.to_s)

  def self.all = self::CATALOG.values

  # The external channels that exist now: the push waits for its flag (D-654), and WhatsApp
  # for its block.
  def self.available_channels
    FeatureFlags.enabled?(FeatureFlags::PUSH_NOTIFICATIONS) ? %w[email push] : %w[email]
  end

  # The types a person with these roles can configure: those with a channel to choose.
  def self.configurable_for(roles)
    all.select { |type| type.configurable_channels(roles).any? && (type.roles == :all || type.roles.intersect?(roles)) }
  end

  def in_bell? = channels.include?("system")

  def external_channels = channels - %w[system]

  # Security notices leave even in the quiet hours (RN-15-033).
  def security? = code.start_with?("security.")

  # Who works with the notices gets those of the work in the daily digest; urgent ones go at
  # once (RN-15-040, RN-15-042), and the person's own, security and the contract's go one by
  # one (RN-15-044, D-655).
  def digest_for?(person_roles)
    return false if urgent || security? || code.start_with?("billing.") || roles == :all

    roles.intersect?(self.class::DIGEST_ROLES & person_roles)
  end

  # Without roles, as for the company's defaults, every channel of the type.
  def configurable_channels(roles = nil)
    available = external_channels & self.class.available_channels
    roles.nil? || push_roles.nil? || push_roles.intersect?(roles) ? available : available - %w[push]
  end
end

# The profiles of the daily digest (RN-15-040).
NotificationType::DIGEST_ROLES = %w[hr_admin hr_analyst consultant manager firm_admin accountant].freeze

NotificationType::CATALOG = [
  # The person. The unlock e-mail is already an access notice (RN-15-011), so the lockout
  # goes to the bell only in phase 1 (D-607). WhatsApp comes in phase 2.
  NotificationType.new(code: "security.account_locked", mandatory: true, urgent: false, channels: %w[system], roles: :all),
  NotificationType.new(code: "security.mfa_reset", mandatory: true, urgent: false, channels: %w[system email], roles: :all),
  # A new passkey survives a new password (P-16-20), so the person is always told (D-647).
  NotificationType.new(code: "security.passkey_added", mandatory: true, urgent: false, channels: %w[system email], roles: :all),
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
  # The NFS-e authorized, with its PDF and XML on the invoice, to the contract's responsible
  # (RN-19-107, D-564, D-633).
  NotificationType.new(code: "billing.nfse_issued", mandatory: true, urgent: false, channels: %w[system email],
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
  # The employment started with the admission open, to the HR (RN-07-085, D-653).
  NotificationType.new(code: "admission.activated_with_pending", mandatory: true, urgent: true, channels: %w[system email push],
    roles: %w[hr_admin hr_analyst consultant]),
  # The end of an experience period, to the HR and the managers; the variants tell the HR what
  # happened by itself (RN-07-101, RN-07-102, D-653).
  NotificationType.new(code: "employments.probation_ending", mandatory: true, urgent: false, channels: %w[system email push],
    roles: %w[hr_admin hr_analyst consultant manager], push_roles: %w[manager]),
  # An admission sent to the accounting firm, to its team (RN-06-065, D-652).
  NotificationType.new(code: "accounting.admission_forwarded", mandatory: false, urgent: false, channels: %w[system email],
    roles: %w[firm_admin accountant]),
  # An item of a process to the client's manager (P-15-35); the person's notice comes with
  # the portal (spec 16, D-641).
  NotificationType.new(code: "processes.task_assigned", mandatory: false, urgent: false, channels: %w[system email],
    roles: %w[client_manager]),
  # An ASO that needs attention, without the result (RN-07-061, RN-15-005, D-651).
  NotificationType.new(code: "admission.aso_unfit", mandatory: true, urgent: true, channels: %w[system email push],
    roles: %w[hr_admin hr_analyst consultant]),
  # A form to review, and one given back to the person (D-649).
  NotificationType.new(code: "processes.form_submitted", mandatory: false, urgent: false, channels: %w[system email],
    roles: %w[hr_admin hr_analyst consultant]),
  NotificationType.new(code: "processes.form_correction_requested", mandatory: false, urgent: false, channels: %w[system],
    roles: %w[employee]),
  # The admission released to who already has access; the others get the invitation
  # (RN-07-020, D-648). WhatsApp comes with spec 15's rest.
  NotificationType.new(code: "admission.started", mandatory: true, urgent: false, channels: %w[system email], roles: %w[employee]),
  # An item past its date, to whoever answers for it and to the process's HR (RN-06-028).
  NotificationType.new(code: "processes.task_overdue", mandatory: false, urgent: false, channels: %w[system email push],
    roles: %w[manager client_manager hr_admin hr_analyst consultant], push_roles: %w[manager]),
  # A document expiring: to the unit's HR, with the link, and to the department's managers,
  # the text only (RN-08-031, P-08-11, D-643).
  NotificationType.new(code: "documents.hr_expiring", mandatory: false, urgent: false, channels: %w[system email],
    roles: %w[hr_admin hr_analyst consultant]),
  NotificationType.new(code: "documents.team_expiring", mandatory: false, urgent: false, channels: %w[system email],
    roles: %w[manager]),
  # The employee's documents in the portal (spec 16, D-645): asked, a correction, expiring
  # and an acknowledgment waiting. WhatsApp comes with its block.
  NotificationType.new(code: "documents.requested", mandatory: false, urgent: false, channels: %w[system push], roles: %w[employee]),
  NotificationType.new(code: "documents.correction_requested", mandatory: false, urgent: false, channels: %w[system push],
    roles: %w[employee]),
  NotificationType.new(code: "documents.expiring", mandatory: false, urgent: false, channels: %w[system push], roles: %w[employee]),
  # A new notice on the board, with the title and the text; the file stays in the system
  # (RN-15-074, D-656). WhatsApp comes with its block.
  NotificationType.new(code: "announcements.published", mandatory: false, urgent: false, channels: %w[system email push],
    roles: %w[employee]),
  # The support imported on the company's behalf (RN-18-062, D-666): the kind and the counts,
  # never people's data (RN-15-005).
  NotificationType.new(code: "imports.assisted_completed", mandatory: false, urgent: false, channels: %w[system email],
    roles: %w[hr_admin]),
  NotificationType.new(code: "documents.acknowledgment_pending", mandatory: true, urgent: false, channels: %w[system email push],
    roles: %w[employee]),
  # A version the employee sent, to the unit's HR (D-645).
  NotificationType.new(code: "documents.review_pending", mandatory: false, urgent: false, channels: %w[system email],
    roles: %w[hr_admin hr_analyst consultant]),
  # A batch with files not distributed, 7 days before it expires, to who sent it
  # (RN-08-062, D-644).
  NotificationType.new(code: "documents.batch_expiring", mandatory: false, urgent: false, channels: %w[system email],
    roles: %w[hr_admin hr_analyst consultant]),
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
    roles: %w[superadmin]),
  # The national holidays brought from BrasilAPI, waiting for the team's review (P-11-06, D-638).
  NotificationType.new(code: "platform.holidays_review", mandatory: true, urgent: false, channels: %w[system email],
    roles: %w[superadmin support])
].index_by(&:code).freeze
