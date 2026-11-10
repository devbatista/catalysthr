# One call to Claude or to Voyage (spec 14, section 7): the function, the tokens, the cost, the
# credits and the status, without the content sent nor the raw answer (RN-14-131, CA-14-014).
# The useful result stays on the subject (the extraction, the batch item). Not tenant-scoped,
# like the usage: every query names the company.
class AiRequest < ApplicationRecord
  STATUSES = %w[succeeded failed].freeze
  PROVIDERS = %w[anthropic voyage].freeze

  belongs_to :company, optional: true
  belongs_to :user, optional: true
  belongs_to :subject, polymorphic: true, optional: true

  validates :feature, inclusion: { in: ->(_) { Ai::Features.codes } }
  validates :status, inclusion: { in: STATUSES }
  validates :provider, inclusion: { in: PROVIDERS }

  scope :succeeded, -> { where(status: "succeeded") }
  scope :failed, -> { where(status: "failed") }

  def succeeded? = status == "succeeded"
end
