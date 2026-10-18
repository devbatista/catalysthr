# A client of the company where its people work allocated (RN-04-091, D-570), with zero or
# more client managers (RN-04-094). The document (CNPJ or CPF) is optional and unique in
# the company. A client with open employments is not inactivated; inactivating takes the
# access away from managers left without an active client (RN-04-096, RN-02-064).
class AllocationClient < ApplicationRecord
  DOCUMENT_TYPES = %w[cnpj cpf].freeze
  STATUSES = %w[active inactive].freeze

  audited

  acts_as_tenant :company

  has_many :allocation_client_managers, dependent: :destroy
  has_many :managers, through: :allocation_client_managers, source: :membership

  enum :document_type, DOCUMENT_TYPES.index_by(&:itself), validate: { allow_nil: true }
  enum :status, STATUSES.index_by(&:itself), validate: true

  normalizes :name, with: ->(name) { name.to_s.squish.presence }
  normalizes :document, with: ->(document) { document.to_s.gsub(/[^0-9A-Za-z]/, "").upcase.presence }

  scope :ordered, -> { order(:name) }

  validates :name, presence: true, length: { maximum: 120 }
  validates :document, uniqueness: { scope: :company_id }, allow_nil: true
  validates :document_type, presence: true, if: :document
  validate :document_valid
  validate :empty_before_inactive, if: -> { status_changed? && inactive? }

  def audit_company_id
    company_id
  end

  def formatted_document
    return if document.nil?

    cpf? ? Cpf.format(document) : Cnpj.format(document)
  end

  private

  def document_valid
    return if document.nil? || document_type.nil?

    valid = cpf? ? Cpf.valid?(document) : Cnpj.valid?(document)
    errors.add(:document, cpf? ? :invalid_cpf : :invalid_cnpj) unless valid
  end

  # RN-04-096, P-04-36 (CA-04-013).
  def empty_before_inactive
    errors.add(:status, :open_employments) if EmploymentRevision.placing_open_employments.exists?(allocation_client_id: id)
  end
end
