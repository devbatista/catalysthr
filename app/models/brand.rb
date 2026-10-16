# Visual and communication settings of a partner, a direct company or a partner's
# company with its own brand (P-01-01, D-159, D-163).
class Brand < ApplicationRecord
  audited

  # CatalystHR defaults for empty fields (RN-01-032), from the visual identity prototype.
  DEFAULT_COLORS = {
    primary: "#085087",
    secondary: "#0A2A4A",
    accent: "#1E9C86"
  }.freeze
  MINIMUM_PRIMARY_CONTRAST = 4.5
  WHITE = "#FFFFFF"
  IMAGE_TYPES = %w[image/png image/jpeg image/webp].freeze
  MAX_IMAGE_SIZE = 2.megabytes
  # E-mail domain in SES (RN-01-040, D-596). No status means not configured.
  EMAIL_DOMAIN_STATUSES = %w[pending verified failed].freeze
  EMAIL_DOMAIN_FORMAT = /\A(?=.{4,253}\z)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+(?:[a-z]{2,63}|xn--[a-z0-9-]{1,59})\z/

  belongs_to :owner, polymorphic: true
  has_many :legal_documents, dependent: :restrict_with_error
  has_many :subdomains, class_name: "BrandSubdomain", dependent: :destroy
  has_one :active_subdomain, -> { active }, class_name: "BrandSubdomain"
  belongs_to :email_domain_registered_by, class_name: "User", optional: true

  has_one_attached :logo_light
  has_one_attached :logo_dark
  has_one_attached :favicon
  has_one_attached :pwa_icon_large
  has_one_attached :pwa_icon_small
  has_one_attached :login_image

  normalizes :primary_color, :secondary_color, :accent_color, with: ->(color) { color.strip.upcase.presence }
  normalizes :email_domain, with: ->(domain) { domain.strip.downcase.delete_suffix(".").presence }

  validates :owner_type, inclusion: { in: %w[Partner Company] }
  validates :commercial_name, presence: true
  validates :primary_color, :secondary_color, :accent_color,
    format: { with: ColorContrast::HEX_FORMAT }, allow_nil: true
  validates :support_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :email_domain, format: { with: EMAIL_DOMAIN_FORMAT }, allow_nil: true
  validates :email_domain_status, inclusion: { in: EMAIL_DOMAIN_STATUSES }, allow_nil: true
  validate :email_domain_available
  validate :primary_color_contrast
  validate :image_attachments

  after_commit :expire_host_lookup

  # Empty colors come from the fallback brand and then from CatalystHR (RN-01-032,
  # RN-01-035).
  def colors(fallback: nil)
    DEFAULT_COLORS.to_h do |name, default|
      [ name, public_send(:"#{name}_color") || fallback&.public_send(:"#{name}_color") || default ]
    end
  end

  # Whether the brand owns a subdomain: a partner's or a direct company's (D-154, D-121).
  # A partner's company with its own brand uses the partner's (RN-01-034).
  def owns_subdomain?
    owner.is_a?(Partner) || (owner.is_a?(Company) && owner.direct?)
  end

  # Only the brand that owns a subdomain has an e-mail domain. A partner's company with
  # its own brand sends from the partner's (P-01-18).
  def email_domain_configurable?
    owns_subdomain?
  end

  def email_domain_verified?
    email_domain.present? && email_domain_status == "verified"
  end

  def app_name
    short_name.presence || commercial_name
  end

  def audit_company_id
    owner_id if owner_type == "Company"
  end

  # Address of a page on the brand's subdomain, for links sent outside a request.
  # Companies reached through this brand's subdomain: the partner's, or the direct
  # company itself (D-154, D-121). A partner's company with its own brand still uses the
  # partner's subdomain.
  def served_companies
    case owner
    when Partner then owner.companies
    when Company then owner.direct? ? Company.where(id: owner_id) : Company.none
    else Company.none
    end
  end

  def panel_url(path = "/", **params)
    PlatformUrl.build("#{active_subdomain.slug}.#{Rails.configuration.x.panel_domain}", path, **params)
  end

  private

  def primary_color_contrast
    return if primary_color.blank? || errors.include?(:primary_color)

    ratio = ColorContrast.ratio(primary_color, WHITE)
    return if ratio >= MINIMUM_PRIMARY_CONTRAST

    errors.add(:primary_color, :low_contrast, ratio: format("%.1f", ratio).tr(".", ","))
  end

  # Neither the platform's domain, its subdomains nor another brand's (D-596). The same
  # message for every case, so the form does not tell whether another brand has it.
  def email_domain_available
    return if email_domain.blank? || errors.include?(:email_domain)

    platform = BrandSender::PLATFORM_DOMAIN
    taken = Brand.where(email_domain: email_domain).where.not(id: id).exists?
    if email_domain == platform || email_domain.end_with?(".#{platform}") || taken
      errors.add(:email_domain, :unavailable)
    end
  end

  # SVG is not accepted: it can carry scripts.
  def image_attachments
    %i[logo_light logo_dark favicon pwa_icon_large pwa_icon_small login_image].each do |name|
      file = public_send(name)
      next unless file.attached?

      errors.add(name, :image_type) unless file.blob.content_type.in?(IMAGE_TYPES)
      errors.add(name, :image_size) if file.blob.byte_size > MAX_IMAGE_SIZE
    end
  end

  def expire_host_lookup
    subdomains.each(&:expire_host_lookup)
  end
end
