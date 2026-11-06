# A person's channels for a notice type, per membership (spec 15, RN-15-021, RN-15-022).
# Without one, the company's default applies, and then the catalog's.
class NotificationPreference < ApplicationRecord
  include NotificationChannels

  audited

  belongs_to :membership

  validates :notification_type, uniqueness: { scope: :membership_id }

  def audit_company_id
    membership.audit_company_id
  end

  private

  def channel_roles = membership&.roles
end
