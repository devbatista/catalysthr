# A change to a feature flag made on the admin's screen (D-617): turned on or off for
# everyone, created from the code's list, or removed when the code no longer has it.
# Changes made through the console are not here.
class FeatureFlagChange < ApplicationRecord
  ACTIONS = %w[enabled disabled declared removed].freeze

  belongs_to :changed_by, class_name: "User"

  validates :flag, presence: true
  validates :action, inclusion: { in: ACTIONS }

  def readonly?
    persisted? || super
  end
end
