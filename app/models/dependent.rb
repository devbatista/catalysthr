# A dependent of the person in the company (RN-04-043, D-208): for the income tax
# (IRRF), the family allowance and the eSocial. The relationship types keep the system's
# own values; the eSocial codes, and whether the CPF is mandatory, are checked in spec 13
# (P-04-15, D-602). The CPF is sensitive (D-086). A dependent who leaves is ended, never
# deleted, so past payrolls keep them (D-604). The certificate comes with spec 08.
class Dependent < ApplicationRecord
  RELATIONSHIP_TYPES = %w[
    spouse partner child stepchild student_child sibling grandchild parent grandparent ward incapable_person
    alimony_recipient other
  ].freeze
  STATUSES = %w[active ended].freeze

  audited sensitive: %i[cpf]

  acts_as_tenant :company

  belongs_to :worker_profile

  encrypts :cpf

  enum :relationship_type, RELATIONSHIP_TYPES.index_by(&:itself), validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true
  enum :sex, WorkerProfile::SEXES.index_by(&:itself), validate: { allow_nil: true }, prefix: true

  normalizes :name, with: ->(name) { name.to_s.squish.presence }
  normalizes :cpf, with: ->(cpf) { Cpf.normalize(cpf).presence }

  scope :ordered, -> { order(Arel.sql("status = 'ended'"), :birth_date) }

  validates :name, presence: true, length: { maximum: 120 }
  validates :birth_date, presence: true
  validates :cpf, cpf: true, allow_nil: true
  validates :ended_on, presence: true, if: :ended?
  validate :born_already

  def audit_company_id
    company_id
  end

  # Ends the dependent on the date (D-604).
  def end!(on:)
    update!(status: "ended", ended_on: on)
  end

  private

  def born_already
    errors.add(:birth_date, :future) if birth_date && birth_date > Date.current
  end
end
