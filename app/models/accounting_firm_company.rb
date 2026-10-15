# The link between an accounting firm and a company (RN-02-070 to RN-02-073):
# pending until the firm accepts, when the firm already existed (P-02-29), then active
# until either side ends it. A refused or cancelled request also ends (D-590).
class AccountingFirmCompany < ApplicationRecord
  # Statuses that hold the company's only link (D-589).
  OPEN_STATUSES = %w[pending active].freeze

  audited

  belongs_to :accounting_firm
  belongs_to :company
  belongs_to :linked_by, class_name: "User", optional: true

  enum :status, { pending: "pending", active: "active", ended: "ended" }, validate: true

  scope :open, -> { where(status: OPEN_STATUSES) }

  validate :one_open_per_company, if: -> { status.in?(OPEN_STATUSES) }

  private

  def one_open_per_company
    others = self.class.open.where(company_id: company_id).where.not(id: id)
    errors.add(:base, :already_linked) if others.exists?
  end
end
