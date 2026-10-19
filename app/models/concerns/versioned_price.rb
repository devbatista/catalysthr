# A price that never changes once saved (D-611): a new price is a new version, numbered
# within its scope, taking effect today or later. Between versions of the same date, the
# one registered last is in force.
#
#   versioned_price scope: :add_on_id
module VersionedPrice
  extend ActiveSupport::Concern

  included do
    class_attribute :price_scope, instance_writer: false

    before_validation :assign_version, on: :create

    validates :version, numericality: { only_integer: true, greater_than: 0 }
    validates :valid_from, presence: true
    validate :not_in_the_past, on: :create
  end

  class_methods do
    def versioned_price(scope: nil)
      self.price_scope = scope
    end

    # The version in force on a date, among the given ones.
    def in_force(versions, date = Date.current)
      versions.select { |version| version.valid_from <= date }.max_by { |version| [ version.valid_from, version.version ] }
    end
  end

  def readonly?
    persisted? || super
  end

  private

  # Two versions saved at the same moment are stopped by the unique index.
  def assign_version
    siblings = price_scope ? self.class.where(price_scope => self[price_scope]) : self.class.all
    self.version ||= (siblings.maximum(:version) || 0) + 1
  end

  # A past price would change what was already sold.
  def not_in_the_past
    errors.add(:valid_from, :past) if valid_from && valid_from < Date.current
  end
end
