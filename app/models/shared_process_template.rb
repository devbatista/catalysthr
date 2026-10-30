# A model of process without a company: the CatalystHR library (no partner) or a
# partner's (spec 06, D-126, D-232). Companies adopt a copy before using it (P-06-01). It
# reads only the rows without a company, so it never reaches a company's models (P-06-19,
# D-639).
class SharedProcessTemplate < ApplicationRecord
  include ProcessTemplateDefinition

  default_scope { where(company_id: nil) }

  belongs_to :partner, optional: true
  belongs_to :source_template, class_name: "SharedProcessTemplate", optional: true
  has_many :items, -> { order(:position) }, class_name: "SharedProcessTemplateItem", foreign_key: :process_template_id,
    inverse_of: :template, dependent: nil

  scope :library, -> { where(partner_id: nil) }

  validate :no_company

  def company_level?
    false
  end

  def library?
    partner_id.nil?
  end

  private

  def no_company
    errors.add(:base, :company_owned) if company_id.present?
  end
end
