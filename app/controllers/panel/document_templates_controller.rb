module Panel
  # The models of contracts and terms, under Empresa, kept by the HR administrator (RN-07-040,
  # RN-07-041, P-07-17). The preview shows the PDF with the variables' names. Behind the
  # `admissions` flag (D-648).
  class DocumentTemplatesController < BaseController
    before_action :require_current_company
    before_action :require_flag
    before_action :load_template, only: %i[edit update preview]

    def index
      authorize! :read, DocumentTemplate
      @templates = DocumentTemplate.accessible_by(current_ability).ordered
    end

    def new
      authorize! :create, DocumentTemplate
      @template = DocumentTemplate.new(employment_kinds: %w[clt])
    end

    def create
      authorize! :create, DocumentTemplate
      @template = DocumentTemplate.new(template_params)
      if @template.save
        redirect_to edit_document_template_path(@template), notice: t(".created")
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize! :update, @template
    end

    def update
      authorize! :update, @template
      if @template.update(template_params)
        redirect_to edit_document_template_path(@template), notice: t(".updated")
      else
        render :edit, status: :unprocessable_content
      end
    end

    def preview
      authorize! :read, @template
      values = @template.variables.index_with { |name| "[#{name}]" }
      pdf = Documents::ContractPdf.new(title: @template.name, body: @template.body, values: values).render
      response.headers["Cache-Control"] = "private, no-store"
      send_data pdf, type: Documents::Upload::PDF, disposition: :inline, filename: "previa.pdf"
    end

    private

    def require_flag
      head :not_found unless FeatureFlags.enabled?(FeatureFlags::ADMISSIONS)
    end

    # Out of the person's reach answers 404 (RN-03-006).
    def load_template
      @template = DocumentTemplate.accessible_by(current_ability, :read).find(params[:id])
    end

    def template_params
      params.expect(document_template: [ :name, :body, :status, { employment_kinds: [] } ])
    end
  end
end
