# A version of the PDF of an acknowledgement item in a library's or a partner's model of
# process (spec 06, D-640). It reads only the rows without a company.
class SharedProcessTemplateMaterial < ApplicationRecord
  include ProcessTemplateMaterialDefinition

  default_scope { where(company_id: nil) }

  belongs_to :item, class_name: "SharedProcessTemplateItem", foreign_key: :process_template_item_id, optional: true,
    inverse_of: :materials
end
