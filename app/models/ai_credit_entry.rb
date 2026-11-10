# The credits a call used, by contract: the base of the quota and of the excess (spec 14,
# RN-14-111, D-384). A failed call has no entry (RN-14-113). A company without a contract still
# has its entries, without the account. Not tenant-scoped, like the usage.
class AiCreditEntry < ApplicationRecord
  KINDS = %w[usage adjustment].freeze

  belongs_to :billing_account, optional: true
  belongs_to :company
  belongs_to :ai_request, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :credits, numericality: { only_integer: true }
  validates :period, presence: true
end
