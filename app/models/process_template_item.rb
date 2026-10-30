# An item of a company's model of process (spec 06, RN-06-010 to RN-06-042). The
# library's and the partner's are SharedProcessTemplateItem, in the same table (D-639).
class ProcessTemplateItem < ApplicationRecord
  include ProcessTemplateItemDefinition

  acts_as_tenant :company

  belongs_to :template, class_name: "ProcessTemplate", foreign_key: :process_template_id, inverse_of: :items
  # Removing the item keeps the versions (D-640); the foreign key empties the link.
  has_many :materials, class_name: "ProcessTemplateMaterial", foreign_key: :process_template_item_id, inverse_of: :item,
    dependent: nil

  def audit_company_id
    company_id
  end
end
