# Access events (spec 05, RN-05-020 to RN-05-022, D-085): who did or saw what, written
# inside the request so nothing is lost if the queue fails. Insert only: nobody edits
# or deletes them; only the retention job removes them after 5 years (D-219).
class AccessEvent < ApplicationRecord
  KINDS = %w[sensitive_read download export auth impersonation admin].freeze

  belongs_to :company, optional: true
  belongs_to :user
  belongs_to :impersonator, class_name: "User", optional: true
  belongs_to :subject, polymorphic: true, optional: true

  enum :kind, KINDS.index_by(&:itself), validate: true

  validates :action, presence: true

  # Request data (IP, browser, request id) comes from Current.
  def self.record!(kind:, action:, user:, subject: nil, company: nil, field: nil, metadata: {})
    create!(
      kind: kind, action: action, user: user, subject: subject, company: company, field: field,
      metadata: metadata, ip: Current.ip, user_agent: Current.user_agent.to_s.first(500).presence,
      request_id: Current.request_id
    )
  end

  def readonly?
    persisted? || super
  end
end
