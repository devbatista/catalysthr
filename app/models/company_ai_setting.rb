# An AI function turned on or off in the company by the HR administrator (spec 14, RN-14-010,
# D-389). Without a row, the function is on (RN-14-011); turning it off keeps what it already
# produced (RN-14-012).
class CompanyAiSetting < ApplicationRecord
  audited

  acts_as_tenant :company

  belongs_to :updated_by, class_name: "User", optional: true

  validates :feature, inclusion: { in: ->(_) { Ai::Features.codes } }, uniqueness: { scope: :company_id }
end
