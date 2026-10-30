module Panel
  # The items of the company's models of process (spec 06, RN-06-010 to RN-06-042, D-639),
  # with the conditions by position, unit and allocation client (RN-06-035, P-06-22).
  class ProcessTemplateItemsController < BaseController
    include ProcessTemplateItemEditing

    # The company comes before the model, read inside it.
    skip_before_action :load_template, :load_item
    before_action :require_current_company
    before_action :load_template
    before_action :load_item, only: %i[edit update destroy move]

    private

    def template_scope
      ProcessTemplate.all
    end

    def route_prefix
      ""
    end
  end
end
