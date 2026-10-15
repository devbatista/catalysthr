# An external accounting firm, with its own team, linked to the companies it serves
# (D-170 to D-172). Not company-scoped: each query names the firm.
class AccountingFirm < ApplicationRecord
  audited

  has_many :accounting_firm_companies, dependent: :restrict_with_error
  has_many :memberships, as: :organization, dependent: :restrict_with_error

  enum :status, { active: "active", inactive: "inactive" }, validate: true

  normalizes :cnpj, with: ->(cnpj) { Cnpj.normalize(cnpj) }

  validates :name, presence: true
  validates :cnpj, presence: true, cnpj: true, uniqueness: true
end
