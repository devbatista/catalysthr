# An item of a company's model of process (spec 06, RN-06-010 to RN-06-042). The
# library's and the partner's are SharedProcessTemplateItem, in the same table (D-639).
class ProcessTemplateItem < ApplicationRecord
  include ProcessTemplateItemDefinition

  acts_as_tenant :company

  belongs_to :template, class_name: "ProcessTemplate", foreign_key: :process_template_id, inverse_of: :items

  def audit_company_id
    company_id
  end
end
