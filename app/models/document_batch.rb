# A batch of files the HR sends at once, such as the 40 ASOs from the clinic (spec 08,
# RN-08-060 to RN-08-063, D-277, D-642, D-644). Files come in rounds of up to 20, up to
# 100; the HR picks each one's type and person, confirms or discards it, and distributes
# the confirmed ones. Nothing reaches a folder without that. A batch not finished expires
# in 30 days, with a notice 7 days before, and its files left are deleted.
class DocumentBatch < ApplicationRecord
  STATUSES = %w[processing awaiting_confirmation distributed expired].freeze
  MAX_FILES = 100
  ROUND_FILES = 20
  LIFETIME = 30.days
  NOTICE_BEFORE = 7.days

  acts_as_tenant :company

  audited

  belongs_to :uploaded_by, class_name: "User"
  has_many :items, -> { order(:created_at, :id) }, class_name: "DocumentBatchItem", inverse_of: :batch, dependent: nil

  enum :status, STATUSES.index_by(&:itself), validate: true

  before_validation -> { self.expires_at ||= LIFETIME.from_now }, on: :create

  def audit_company_id
    company_id
  end

  def open?
    awaiting_confirmation? && expires_at.future?
  end

  def room
    MAX_FILES - items.size
  end
end
