# A module the partner turned on or off for a company of the portfolio (RN-19-012,
# D-616). The partner's contract says which modules exist; this row says whether the
# company uses each one. A company without the row does not use the module. Not
# tenant-scoped: the partner's panel has no current company, and every query names the
# company.
class CompanyModuleSetting < ApplicationRecord
  audited

  belongs_to :company
  belongs_to :changed_by, class_name: "User"

  validates :module, inclusion: { in: PlanModule::MODULES }, uniqueness: { scope: :company_id }
  validates :changed_at, presence: true

  # Turns each of the partner's contracted modules on or off for the company, as in
  # `codes`, recording who changed it (RN-19-012). Only what changed is written; two
  # saves at the same time wait for each other.
  def self.apply(company, codes, by:)
    company.with_lock do
      company.partner.contracted_modules.each do |code|
        setting = company.module_settings.find_or_initialize_by(module: code)
        enabled = codes.include?(code)
        next if setting.persisted? && setting.enabled == enabled

        setting.update!(enabled: enabled, changed_by: by, changed_at: Time.current)
      end
    end
  end
end
