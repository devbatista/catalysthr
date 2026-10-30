# A version of the PDF of an acknowledgement item in a company's model of process (spec
# 06, RN-06-060, D-640). The library's and the partner's are SharedProcessTemplateMaterial,
# in the same table.
class ProcessTemplateMaterial < ApplicationRecord
  include ProcessTemplateMaterialDefinition

  acts_as_tenant :company

  belongs_to :item, class_name: "ProcessTemplateItem", foreign_key: :process_template_item_id, optional: true,
    inverse_of: :materials

  def audit_company_id
    company_id
  end
end
