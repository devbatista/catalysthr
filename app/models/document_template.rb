# A model of contract or term (RN-07-040, RN-07-041, D-253): text with simple markup and
# variables, valid for the employment kinds chosen. Only the HR administrator keeps them
# (P-07-17). A variable outside the catalog, or a character the PDF's font doesn't have, is
# refused on saving, so nothing comes out wrong in a contract (D-650).
class DocumentTemplate < ApplicationRecord
  STATUSES = %w[active inactive].freeze
  MAX_BODY = 50_000

  acts_as_tenant :company

  audited

  has_many :generated_documents, dependent: :restrict_with_error

  enum :status, STATUSES.index_by(&:itself), validate: true

  normalizes :name, with: ->(name) { name.to_s.squish.presence }
  normalizes :body, with: ->(text) { text.to_s.gsub("\r\n", "\n").strip.presence }
  normalizes :employment_kinds, with: ->(kinds) { Array(kinds).compact_blank.uniq }

  scope :ordered, -> { order(:name) }
  scope :for_kind, ->(kind) { where("? = ANY(employment_kinds)", kind) }

  validates :name, presence: true, length: { maximum: 120 }
  validates :body, presence: true, length: { maximum: MAX_BODY }
  validates :employment_kinds, presence: true
  validate :kinds_known
  validate :variables_known
  validate :characters_supported

  def audit_company_id
    company_id
  end

  # The catalog's names the text uses, in order, without repeating (RN-07-042).
  def variables
    Documents::TemplateVariables.used_in(body)
  end

  private

  def kinds_known
    errors.add(:employment_kinds, :inclusion) if (employment_kinds - Employment::KINDS).any?
  end

  def variables_known
    unknown = Documents::TemplateVariables.unknown_in(body)
    errors.add(:body, :unknown_variables, names: unknown.join(", ")) if unknown.any?
  end

  def characters_supported
    chars = Documents::ContractPdf.unsupported("#{name}#{body}")
    errors.add(:body, :unsupported_characters, chars: chars.join(" ")) if chars.any?
  end
end
