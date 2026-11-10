# What the AI read from a document (spec 14, RN-14-020 to RN-14-024, D-670): the type it sees,
# the fields of the type's profile with the page and the confidence, the visual signs and the
# result of the system's checks. The fields carry personal data, so they stay encrypted and out
# of the versions (D-086); the checks keep only results, never values. Nothing here changes the
# record: the HR applies on approving (RN-14-001, RN-08-021).
class AiExtraction < ApplicationRecord
  STATUSES = %w[queued processing succeeded retrying failed].freeze

  acts_as_tenant :company

  belongs_to :subject, polymorphic: true
  belongs_to :ai_request, optional: true

  serialize :fields, coder: JSON
  encrypts :fields

  enum :status, STATUSES.index_by(&:itself), validate: true

  # The field read, by key: { "value" =>, "confidence" =>, "page" => }.
  def field(key)
    Array(fields).find { |field| field["key"] == key.to_s }
  end

  def value(key) = field(key)&.dig("value")
end
