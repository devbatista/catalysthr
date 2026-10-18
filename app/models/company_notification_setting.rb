# The company's default channels for a notice type, set by the HR administrator
# (spec 15, RN-15-020). The company starts with the catalog's channels.
class CompanyNotificationSetting < ApplicationRecord
  include NotificationChannels

  audited

  acts_as_tenant :company

  validates :notification_type, uniqueness: { scope: :company_id }
end
