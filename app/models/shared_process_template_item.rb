# An item of a library's or a partner's model of process (spec 06, D-639). It reads only
# the rows without a company, so it never reaches a company's items.
class SharedProcessTemplateItem < ApplicationRecord
  include ProcessTemplateItemDefinition

  default_scope { where(company_id: nil) }

  belongs_to :template, class_name: "SharedProcessTemplate", foreign_key: :process_template_id, inverse_of: :items
end
