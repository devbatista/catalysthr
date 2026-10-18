# A person (spec 02). Signs in with CPF or e-mail plus password (D-054, RN-02-003).
# The CatalystHR team is marked by platform_role, without a membership (P-02-01).
class User < ApplicationRecord
  PLATFORM_ROLES = %w[superadmin support finance].freeze
  # Roles that make MFA mandatory in every sign-in, in any organization (RN-02-040,
  # RN-02-041, D-082, P-02-39). The CatalystHR team always uses it.
  MFA_REQUIRED_ROLES = %w[partner_admin consultant hr_admin hr_analyst client_manager].freeze

  # two_factor_authenticatable replaces database_authenticatable: having both would let
  # the password alone pass the sign-in (devise-two-factor). 10 single-use recovery
  # codes (RN-02-042, D-083).
  devise :two_factor_authenticatable, :two_factor_backupable, :recoverable, :lockable, :trackable,
    authentication_keys: [ :login ], reset_password_keys: [ :login ], unlock_keys: [ :login ],
    otp_number_of_backup_codes: 10, otp_backup_code_length: 5

  # Deterministic, so the CPF can be searched and kept unique (RN-02-001, D-086).
  encrypts :cpf, deterministic: true

  # Sign-in bookkeeping changes on every sign-in and is not a change of the person's data.
  audited sensitive: %i[cpf],
    secret: %i[encrypted_password reset_password_token reset_password_sent_at unlock_token otp_secret
      otp_backup_codes consumed_timestep],
    ignore: %i[sign_in_count current_sign_in_at last_sign_in_at current_sign_in_ip last_sign_in_ip
      failed_attempts locked_at]

  has_many :memberships, dependent: :restrict_with_error
  has_many :consents, dependent: :restrict_with_error
  has_many :trusted_devices, dependent: :delete_all
  has_many :user_sessions, dependent: :delete_all

  enum :status, { active: "active", deactivated: "deactivated" }, validate: true
  enum :platform_role, PLATFORM_ROLES.index_by(&:itself), validate: { allow_nil: true }
  # Whether the e-mail still receives (RN-15-083, D-609): a permanent bounce stops every
  # e-mail; a spam complaint stops the optional notices.
  enum :email_status, { valid: "valid", bounced: "bounced", complained: "complained" }, prefix: :email, validate: true

  normalizes :cpf, with: ->(cpf) { Cpf.normalize(cpf) }
  normalizes :email, with: ->(email) { email.strip.downcase.presence }
  normalizes :mobile_phone, with: ->(phone) { phone.gsub(/\D/, "").presence }

  # The sign-in field: a CPF, with or without punctuation, or an e-mail (P-02-05).
  attr_accessor :login

  validates :name, presence: true
  validates :cpf, presence: true, cpf: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true, allow_nil: true
  validates :password, password_policy: true, confirmation: true
  validate :email_or_mobile_phone

  # A new e-mail starts valid (RN-15-083).
  before_save :reset_email_status, if: -> { will_save_change_to_email? && !email_valid? }

  # A new password ends the other sessions and forgets the remembered devices
  # (RN-02-043, RN-02-053). The current session, if any, stays open.
  after_update :end_access_after_password_change, if: :saved_change_to_encrypted_password?

  # Who may sign in where (RN-02-004, RN-01-002): the CatalystHR team only at the
  # admin host; everyone else only at a brand where they hold an active or read-only
  # membership. Anyone else is not found, so the answer is the same "invalid
  # credentials" (P-01-03).
  def self.allowed_at(area:, brand:)
    case area
    when :admin then where.not(platform_role: nil)
    when :panel then where(platform_role: nil, id: Membership.with_access.for_brand(brand).select(:user_id))
    else none
    end
  end

  def self.find_by_login(login)
    login = login.to_s.strip
    return if login.empty?

    Cpf.looks_like_cpf?(login) ? find_by(cpf: login) : find_by(email: login)
  end

  # Devise lookups for sign-in, recovery and unlock, limited to the current area.
  def self.find_for_database_authentication(conditions)
    allowed_at(area: Current.area, brand: Current.brand).find_by_login(conditions[:login])
  end

  # Recovery by e-mail (RN-02-033). Without an e-mail, recovery is by WhatsApp,
  # which comes with Twilio. The answer never says whether the person exists (RN-02-034).
  def self.send_reset_password_instructions(attributes = {})
    user = find_for_database_authentication(attributes)
    user&.send_reset_password_instructions
    user || new(login: attributes[:login])
  end

  # Unlock by e-mail (RN-02-031), only for a locked account.
  def self.send_unlock_instructions(attributes = {})
    user = find_for_database_authentication(attributes)
    user&.resend_unlock_instructions
    user || new(login: attributes[:login])
  end

  def active_for_authentication?
    super && active?
  end

  # Deactivated people get the same answer as unknown ones (P-01-03).
  def inactive_message
    active? ? super : :invalid
  end

  def first_name
    name.split.first
  end

  # An invited person has no password until the first access (RN-02-014).
  def password_set?
    encrypted_password.present?
  end

  def mfa_required?
    platform_role.present? ||
      memberships.where.not(status: "revoked").where("roles && ARRAY[?]::varchar[]", MFA_REQUIRED_ROLES).exists?
  end

  def mfa_enabled?
    otp_required_for_login?
  end

  # Turns on the authenticator after the person proves it works with a first code.
  # Returns the recovery codes, shown only once (RN-02-042).
  def enable_mfa!(secret:, code:)
    return unless validate_and_consume_otp!(code, otp_secret: secret)

    self.otp_secret = secret
    self.otp_required_for_login = true
    codes = generate_otp_backup_codes!
    save!(validate: false)
    record_auth_event("mfa_enabled")
    codes
  end

  # By the person, or by who administers the profile or the support (RN-02-044, D-582),
  # which is a reset.
  def disable_mfa!(by: self, reason: nil)
    update!(otp_secret: nil, otp_required_for_login: false, otp_backup_codes: nil, consumed_timestep: nil)
    AccessEvent.record!(kind: "auth", action: by == self ? "mfa_disabled" : "mfa_reset", user: by, subject: self,
      metadata: { reason: reason }.compact)
  end

  # New codes replace the previous ones (RN-02-042, P-02-20).
  def regenerate_recovery_codes!
    codes = generate_otp_backup_codes!
    save!(validate: false)
    record_auth_event("recovery_codes_regenerated")
    codes
  end

  # Whether an e-mail may go out: none to a bounced address, and only mandatory notices to
  # an address that complained of spam (RN-15-083, D-609).
  def email_deliverable?(mandatory: true)
    email.present? && !email_bounced? && (mandatory || !email_complained?)
  end

  # Lockout and unlock become access events (RN-05-020). The lockout is also a notice in
  # the bell; the unlock e-mail is the access notice (RN-15-011, D-607).
  def lock_access!(options = {})
    super.tap do
      record_auth_event("locked")
      Notifications.notify!("security.account_locked", user: self, path: "/security")
    end
  end

  def unlock_access!
    super.tap { record_auth_event("unlocked") }
  end

  def record_auth_event(action, **metadata)
    AccessEvent.record!(kind: "auth", action: action, user: self, subject: self, metadata: metadata)
  end

  # A code from the app or a recovery code, used once.
  def valid_second_factor?(code)
    code = code.to_s.strip
    return false if code.empty?

    validate_and_consume_otp!(code) || invalidate_otp_backup_code!(code.downcase)
  end

  def revoke_sessions!(reason:, except: nil)
    user_sessions.active.where.not(id: except).update_all(revoked_at: Time.current, revoked_reason: reason)
  end

  private

  def end_access_after_password_change
    revoke_sessions!(reason: "password_changed", except: Current.user_session&.id)
    trusted_devices.active.update_all(revoked_at: Time.current)
    record_auth_event(encrypted_password_before_last_save.blank? ? "password_created" : "password_changed")
  end

  def reset_email_status
    self.email_status = "valid"
    self.email_status_at = Time.current
  end

  # RN-02-002, P-02-04: without e-mail or mobile phone there is no way to recover access.
  def email_or_mobile_phone
    errors.add(:base, :email_or_mobile_phone) if email.blank? && mobile_phone.blank?
  end

  # E-mails go out after the request, with the brand and address it came from, so the
  # links open the same subdomain (RN-01-003) and the sender is the brand (RN-01-040).
  # Without an e-mail, or to a bounced one, nothing is sent (D-609); the WhatsApp code comes
  # with Twilio (RN-02-033).
  def send_devise_notification(notification, *args)
    return unless email_deliverable?

    options = args.extract_options!
    options[:brand_id] = Current.brand&.id
    options[:url_options] = Current.url_options
    devise_mailer.public_send(notification, self, *args, options).deliver_later
  end
end
