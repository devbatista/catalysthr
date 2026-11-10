# A weight in credits of an AI function, from a date on, set by the superadmin (spec 14,
# RN-14-110, P-14-05, P-14-36). Before the first one, the spec's table holds (Ai::Features). A
# weight already in force is not changed: a new one starts on a later date.
class AiCreditWeight < ApplicationRecord
  audited

  belongs_to :created_by, class_name: "User", optional: true

  validates :feature, inclusion: { in: ->(_) { Ai::Features.codes } }
  validates :credits, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 1_000 }
  validates :unit, inclusion: { in: %w[request page_block] }
  validates :valid_from, presence: true, uniqueness: { scope: :feature }
  validate :starts_after_today, on: :create

  # The weight of the function on the date.
  def self.credits_on(feature, date = Date.current)
    where(feature: feature.to_s, valid_from: ..date).order(valid_from: :desc).pick(:credits) || Ai::Features.find(feature).credits
  end

  private

  def starts_after_today
    errors.add(:valid_from, :after_today) if valid_from && valid_from <= Date.current
  end
end
