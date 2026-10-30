# A company's model of process (spec 06, D-240): processes only use these (P-06-01). It
# may be the default of its kind (RN-06-003) and, for an admission, start an onboarding
# when it ends (RN-06-004). The library's and the partner's models are
# SharedProcessTemplate, in the same table without a company (D-639).
class ProcessTemplate < ApplicationRecord
  include ProcessTemplateDefinition

  acts_as_tenant :company

  has_many :items, -> { order(:position) }, class_name: "ProcessTemplateItem", inverse_of: :template, dependent: nil
  belongs_to :source_template, class_name: "SharedProcessTemplate", optional: true
  belongs_to :onboarding_template, class_name: "ProcessTemplate", optional: true
  has_many :positions, foreign_key: :admission_template_id, inverse_of: :admission_template, dependent: nil

  validate :onboarding_link
  validate :default_only_when_active

  def audit_company_id
    company_id
  end

  def company_level?
    true
  end

  # The company's default of the kind; the previous one stops being it (RN-06-003).
  def make_default!
    transaction do
      self.class.where(kind: kind, is_default: true).where.not(id: id).find_each { |other| other.update!(is_default: false) }
      update!(is_default: true)
    end
  end

  private

  def onboarding_link
    return if onboarding_template_id.nil?

    errors.add(:onboarding_template, :only_admission) unless admission?
    errors.add(:onboarding_template, :invalid) unless onboarding_template&.onboarding? && onboarding_template.company_id == company_id
  end

  def default_only_when_active
    errors.add(:is_default, :not_active) if is_default && !active?
  end
end
