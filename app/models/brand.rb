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

  belongs_to :owner, polymorphic: true
  has_many :legal_documents, dependent: :restrict_with_error
  has_many :subdomains, class_name: "BrandSubdomain", dependent: :destroy
  has_one :active_subdomain, -> { active }, class_name: "BrandSubdomain"

  has_one_attached :logo_light
  has_one_attached :logo_dark
  has_one_attached :favicon
  has_one_attached :pwa_icon_large
  has_one_attached :pwa_icon_small
  has_one_attached :login_image

  normalizes :primary_color, :secondary_color, :accent_color, with: ->(color) { color.strip.upcase.presence }

  validates :owner_type, inclusion: { in: %w[Partner Company] }
  validates :commercial_name, presence: true
  validates :primary_color, :secondary_color, :accent_color,
    format: { with: ColorContrast::HEX_FORMAT }, allow_nil: true
  validates :support_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validate :primary_color_contrast
  validate :image_attachments

  after_commit :expire_host_lookup

  def colors
    {
      primary: primary_color || DEFAULT_COLORS[:primary],
      secondary: secondary_color || DEFAULT_COLORS[:secondary],
      accent: accent_color || DEFAULT_COLORS[:accent]
    }
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
    config = Rails.configuration.x
    url = "#{config.panel_protocol}://#{active_subdomain.slug}.#{config.panel_domain}#{path}"
    params.any? ? "#{url}?#{params.to_query}" : url
  end

  private

  def primary_color_contrast
    return if primary_color.blank? || errors.include?(:primary_color)

    ratio = ColorContrast.ratio(primary_color, WHITE)
    return if ratio >= MINIMUM_PRIMARY_CONTRAST

    errors.add(:primary_color, :low_contrast, ratio: format("%.1f", ratio).tr(".", ","))
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
