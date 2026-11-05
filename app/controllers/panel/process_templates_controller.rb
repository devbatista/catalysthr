module Panel
  # The company's models of process, under Empresa (spec 06, D-240, D-639): the HR
  # administrator keeps them, adopts the partner's and the library's active ones (P-06-01,
  # P-06-02) and marks the default of each kind (RN-06-003). Processes only use these.
  class ProcessTemplatesController < BaseController
    include ProcessTemplateEditing

    # The company comes before the model, read inside it.
    skip_before_action :load_template
    before_action :require_current_company
    before_action :load_template, only: %i[show edit update activate archive material]

    # The company's default of the kind, only an active model (RN-06-003).
    def default
      template = template_scope.accessible_by(current_ability, :read).find(params[:id])
      authorize! :update, template
      if template.active?
        template.make_default!
        redirect_to process_template_path(template), notice: t("process_templates.made_default")
      else
        redirect_to process_template_path(template), alert: t("process_templates.default_not_active")
      end
    end

    # The employment kinds this admission model is the default of (RN-07-013, D-648).
    def default_kinds
      template = template_scope.accessible_by(current_ability, :read).find(params[:id])
      authorize! :update, template
      if template.admission? && template.active?
        template.make_default_for!(params[:employment_kinds])
        redirect_to process_template_path(template), notice: t("process_templates.made_default_kinds")
      else
        redirect_to process_template_path(template), alert: t("process_templates.default_not_active")
      end
    end

    private

    def template_scope
      ProcessTemplate.all
    end

    def build_template(attributes)
      ProcessTemplate.new(attributes)
    end

    # The partner's models for a partner's company, and the library's (P-06-02).
    def adoptable_scope
      SharedProcessTemplate.where(partner_id: [ nil, Current.company.partner_id ].uniq).active
    end

    def adopt_into
      Current.company
    end

    def route_prefix
      ""
    end
  end
end
