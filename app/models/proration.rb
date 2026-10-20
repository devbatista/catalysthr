# The proportional charge of a change in the middle of a cycle (RN-19-060, D-612, D-620):
# an increase of plan, a module or an add-on contracted, or the partner's activation. It
# covers the days from the change to the end of the cycles already invoiced and goes into
# the next invoice, once. Never changes.
class Proration < ApplicationRecord
  KINDS = %w[plan module add_on activation].freeze

  belongs_to :billing_account
  belongs_to :created_by, class_name: "User", optional: true
  has_one :invoice_line, dependent: :restrict_with_exception

  enum :kind, KINDS.index_by(&:itself), prefix: true, validate: true

  validates :description, :effective_on, :total_cents, presence: true

  # Not yet in an invoice.
  scope :pending, -> { where.missing(:invoice_line) }

  def readonly?
    persisted? || super
  end
end
