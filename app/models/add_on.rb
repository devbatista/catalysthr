# An add-on with a fixed monthly price (RN-19-013): for now, the company's own WhatsApp
# number (D-161); face recognition joins when it exists (D-312). The add-on is created
# with its first price, and prices have versions like the plans' (D-611).
class AddOn < ApplicationRecord
  audited

  CODES = %w[whatsapp_sender].freeze
  STATUSES = %w[active inactive].freeze

  # Prices are saved on their own, never through the add-on (Admin::AddOnPricesController).
  has_many :prices, -> { order(:version) }, class_name: "AddOnPrice", inverse_of: :add_on, dependent: :restrict_with_exception,
    validate: false, autosave: false

  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :code, inclusion: { in: CODES }, uniqueness: true

  # The price in force on a date, with the same rule as the plan versions (D-611).
  def price_on(date = Date.current)
    AddOnPrice.in_force(prices, date)
  end

  def latest_price
    prices.max_by(&:version)
  end
end
