# The HR administrator's authorization for the CatalystHR support to import on the company's
# behalf (RN-18-061, P-18-18, D-666): 30 days from the acceptance, revocable at any time. A
# new one replaces the one in force. The text accepted also declares that the bank accounts
# the support imports in the period are in the people's CPF, as the files the company sends
# show (P-04-17, D-666).
class AssistedImportAuthorization < ApplicationRecord
  VALIDITY = 30.days

  audited

  acts_as_tenant :company

  belongs_to :authorized_by, class_name: "User"
  belongs_to :revoked_by, class_name: "User", optional: true

  validates :authorized_at, :valid_until, presence: true

  scope :in_force, -> { where(revoked_at: nil).where("valid_until > ?", Time.current) }

  def self.current
    in_force.order(authorized_at: :desc).first
  end

  # Replaces the one in force, if any.
  def self.grant!(by:)
    transaction do
      in_force.find_each { |authorization| authorization.revoke!(by: by) }
      create!(authorized_by: by, authorized_at: Time.current, valid_until: VALIDITY.from_now)
    end
  end

  def revoke!(by:)
    update!(revoked_at: Time.current, revoked_by: by)
  end

  def audit_company_id
    company_id
  end
end
