# A person (spec 02). Signs in with CPF or e-mail plus password (D-054, RN-02-003).
# The CatalystHR team is marked by platform_role, without a membership (P-02-01).
class User < ApplicationRecord
  PLATFORM_ROLES = %w[superadmin support finance].freeze

  devise :database_authenticatable, :recoverable, :lockable, :trackable,
    authentication_keys: [ :login ], reset_password_keys: [ :login ], unlock_keys: [ :login ]

  # Deterministic, so the CPF can be searched and kept unique (RN-02-001, D-086).
  encrypts :cpf, deterministic: true

  has_many :memberships, dependent: :restrict_with_error

  enum :status, { active: "active", deactivated: "deactivated" }, validate: true
  enum :platform_role, PLATFORM_ROLES.index_by(&:itself), validate: { allow_nil: true }

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

  private

  # RN-02-002, P-02-04: without e-mail or mobile phone there is no way to recover access.
  def email_or_mobile_phone
    errors.add(:base, :email_or_mobile_phone) if email.blank? && mobile_phone.blank?
  end

  # E-mails go out after the request, with the brand and address it came from, so the
  # links open the same subdomain (RN-01-003) and the sender is the brand (RN-01-040).
  # Without an e-mail nothing is sent; the WhatsApp code comes with Twilio (RN-02-033).
  def send_devise_notification(notification, *args)
    return if email.blank?

    options = args.extract_options!
    options[:brand_id] = Current.brand&.id
    options[:url_options] = Current.url_options
    devise_mailer.public_send(notification, self, *args, options).deliver_later
  end
end
