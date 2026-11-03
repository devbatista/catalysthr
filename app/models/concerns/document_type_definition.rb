# What every document type has, the platform's or a company's (spec 08, RN-08-001 to
# RN-08-004, D-270): its category, whether the employee sees it (D-274), whether it asks
# for an acknowledgment (D-279), the expiration rule (D-272, D-275) and how many files a
# version takes (RN-08-011).
module DocumentTypeDefinition
  extend ActiveSupport::Concern

  STATUSES = %w[active archived].freeze
  EXPIRATION_RULES = %w[none document_date periodicity age].freeze
  # Up to 5 images in a version, joined in one PDF (P-08-05).
  MAX_FILES = 5
  MAX_ALERT_DAYS = 365

  included do
    self.table_name = "document_types"

    audited

    enum :status, STATUSES.index_by(&:itself), validate: true
    enum :expiration_rule, EXPIRATION_RULES.index_by(&:itself), validate: true, prefix: :expires_by

    normalizes :name, with: ->(name) { name.to_s.squish.presence }
    normalizes :description, with: ->(text) { text.to_s.strip.presence }

    before_validation :clean_expiration

    validates :name, presence: true, length: { maximum: 120 }
    validates :description, length: { maximum: 1000 }
    validates :category, inclusion: { in: DocumentCategory::ALL }
    validates :max_files, numericality: { only_integer: true, in: 1..MAX_FILES }
    validates :alert_days, numericality: { only_integer: true, in: 1..MAX_ALERT_DAYS }
    validates :expiration_months, numericality: { only_integer: true, in: 1..120 }, if: :expires_by_periodicity?
    validates :max_age_days, numericality: { only_integer: true, in: 1..3650 }, if: :expires_by_age?

    scope :ordered, -> { order(:name) }
  end

  def sensitive?
    DocumentCategory.sensitive?(category)
  end

  def platform?
    company_id.nil?
  end

  private

  def clean_expiration
    self.expiration_months = nil unless expires_by_periodicity?
    self.max_age_days = nil unless expires_by_age?
  end
end
