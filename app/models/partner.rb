# A partner resells the platform under its own brand to its client companies
# (D-120). Partner data is not company-scoped and does not use acts_as_tenant (D-151).
class Partner < ApplicationRecord
  audited

  has_one :brand, as: :owner, dependent: :destroy
  has_many :companies, dependent: :restrict_with_error
  has_many :memberships, as: :organization, dependent: :restrict_with_error

  normalizes :cnpj, with: ->(cnpj) { Cnpj.normalize(cnpj) }

  validates :name, :legal_name, presence: true
  validates :cnpj, presence: true, cnpj: true, uniqueness: true
end
