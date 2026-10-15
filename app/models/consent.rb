# Every acceptance and consent, with what was shown and when (RN-02-015, P-02-10): the
# kind, the version of the text, the decision, the moment, the IP and the user agent.
class Consent < ApplicationRecord
  KINDS = %w[terms privacy biometrics whatsapp].freeze

  belongs_to :user
  belongs_to :scope, polymorphic: true
  belongs_to :legal_document, optional: true

  enum :kind, KINDS.index_by(&:itself), validate: true

  scope :granted, -> { where(granted: true, revoked_at: nil) }

  validates :document_version, :decided_at, presence: true
  validates :granted, inclusion: { in: [ true, false ] }
  validates :legal_document, presence: true, if: -> { terms? || privacy? }

  # Records the acceptance of a published version of the terms or of the policy.
  def self.accept!(user:, legal_document:, scope:, ip:, user_agent:)
    create!(
      user: user, kind: legal_document.kind, scope: scope, legal_document: legal_document,
      document_version: legal_document.version, granted: true, decided_at: Time.current,
      ip: ip, user_agent: user_agent.to_s.first(500)
    )
  end
end
