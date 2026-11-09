# A line of an import's file (spec 18, section 5): what was read, its errors and the fields it
# would change, all encrypted, since they carry personal data and the messages repeat the
# value (D-086, D-661). After 90 days the data leave and the messages stay without the values
# (RN-18-010).
class DataImportRow < ApplicationRecord
  STATUSES = %w[valid invalid unchanged imported failed].freeze
  ACTIONS = %w[create update none].freeze

  acts_as_tenant :company

  belongs_to :data_import, inverse_of: :rows

  enum :status, STATUSES.index_by(&:itself), validate: true, prefix: true
  enum :action, ACTIONS.index_by(&:itself), validate: true, prefix: true

  # The values read, by column; the errors as [{ "column", "value", "message" }]; the
  # changes as { "column" => [before, after] }.
  serialize :payload, coder: JSON
  serialize :issues, coder: JSON
  serialize :diff, coder: JSON
  encrypts :payload, :issues, :diff

  def issues
    super || []
  end

  def diff
    super || {}
  end

  def payload
    super || {}
  end
end
