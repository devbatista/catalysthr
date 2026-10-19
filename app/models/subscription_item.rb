# A module or an add-on of a subscription, from a date (spec 19, section 7). The module's
# price comes from the subscription's plan version; the add-on keeps the price version it
# was sold with (D-611). Ending one sets ends_on; changes come with block 19d.
class SubscriptionItem < ApplicationRecord
  audited

  KINDS = %w[module add_on].freeze

  belongs_to :subscription, inverse_of: :items
  belongs_to :add_on_price, optional: true

  # Prefixed: the column `module` already gives module?.
  enum :kind, KINDS.index_by(&:itself), prefix: true, validate: true

  validates :starts_on, presence: true
  validates :module, inclusion: { in: PlanModule::MODULES }, if: :kind_module?
  validates :module, absence: true, if: :kind_add_on?
  validates :add_on_price, presence: true, if: :kind_add_on?
  validates :add_on_price, absence: true, if: :kind_module?

  def current?(date = Date.current)
    starts_on <= date && (ends_on.nil? || ends_on >= date)
  end
end
