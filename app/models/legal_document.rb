# A published version of the terms of use or of the privacy policy (D-577). Without a
# brand, it is the CatalystHR text, used by brands without their own (RN-01-032,
# D-578). Versions are never edited: a change is a new version (RN-02-017).
class LegalDocument < ApplicationRecord
  audited

  KINDS = %w[terms privacy].freeze

  belongs_to :brand, optional: true
  belongs_to :published_by, class_name: "User"

  enum :kind, KINDS.index_by(&:itself), validate: true

  scope :platform, -> { where(brand_id: nil) }

  before_validation :assign_version, on: :create

  validates :body, presence: true
  validates :version, numericality: { only_integer: true, greater_than: 0 }

  # The text in force for a brand: its latest version or, without one, the CatalystHR's.
  def self.current_for(brand, kind)
    brand_version = where(brand: brand, kind: kind).order(version: :desc).first if brand
    brand_version || platform.where(kind: kind).order(version: :desc).first
  end

  def readonly?
    persisted? || super
  end

  private

  # Two publications at the same moment are stopped by the unique index.
  def assign_version
    self.published_at ||= Time.current
    self.version ||= (self.class.where(brand_id: brand_id, kind: kind).maximum(:version) || 0) + 1
  end
end
