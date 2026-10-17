# Someone to call in an emergency, one or more per person (RN-04-041).
class EmergencyContact < ApplicationRecord
  audited

  acts_as_tenant :company

  belongs_to :worker_profile

  normalizes :name, :relationship, with: ->(value) { value.to_s.squish.presence }
  normalizes :phone, with: ->(phone) { phone.to_s.gsub(/\D/, "").presence }

  validates :name, presence: true, length: { maximum: 120 }
  validates :relationship, length: { maximum: 60 }
  validates :phone, presence: true, format: { with: /\A\d{10,13}\z/, allow_nil: true }

  def audit_company_id
    company_id
  end
end
