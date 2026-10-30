# The models of process at the three levels (spec 06, D-639): the CatalystHR library in
# the admin, the partner's in its panel and the company's under Empresa. Each controller
# says where its models come from (template_scope), how a new one is born (build_template),
# what it may adopt (adoptable_scope, adopt_into) and its routes' prefix (route_prefix).
module ProcessTemplateEditing
  extend ActiveSupport::Concern
  include ProcessTemplateRoutes

  included do
    helper_method :template_model
    before_action :load_template, only: %i[show edit update activate archive material]
  end

  def index
    authorize! :read, template_model
    @templates = template_scope.accessible_by(current_ability).includes(:items).ordered
    @adoptable = adoptable_scope.accessible_by(current_ability, :adopt).includes(:items, :partner).ordered
    render "shared/process_templates/index"
  end

  def show
    authorize! :read, @template
    @items = @template.items_with_materials
    render "shared/process_templates/show"
  end

  def new
    @template = build_template(kind: params[:kind].presence_in(ProcessTemplateDefinition::KINDS) || "admission")
    authorize! :create, @template
    render "shared/process_templates/new"
  end

  def create
    @template = build_template(template_params(new_record: true))
    authorize! :create, @template

    if @template.save
      redirect_to template_route(:template, @template), notice: t("process_templates.created")
    else
      render "shared/process_templates/new", status: :unprocessable_content
    end
  end

  def edit
    authorize! :update, @template
    return archived_redirect unless @template.editable?

    render "shared/process_templates/edit"
  end

  def update
    authorize! :update, @template
    return archived_redirect unless @template.editable?

    if @template.update(template_params(new_record: false))
      redirect_to template_route(:template, @template), notice: t("process_templates.updated")
    else
      render "shared/process_templates/edit", status: :unprocessable_content
    end
  end

  # Every acknowledgement item needs its PDF already scanned (D-640).
  def activate
    authorize! :update, @template
    if !@template.draft? || @template.update(status: "active")
      redirect_to template_route(:template, @template), notice: t("process_templates.activated")
    else
      redirect_to template_route(:template, @template), alert: @template.errors.full_messages.to_sentence
    end
  end

  def archive
    authorize! :update, @template
    @template.archive!
    redirect_to template_route(:template, @template), notice: t("process_templates.archived")
  end

  # A copy of an active model of another level, born a draft (P-06-01, D-232).
  def adopt
    source = adoptable_scope.accessible_by(current_ability, :adopt).find(params[:source_id])
    authorize! :adopt, source
    authorize! :create, build_template(kind: source.kind)
    copy = ProcessTemplates::Adopt.call(source, into: adopt_into, by: current_user)
    redirect_to template_route(:template, copy), notice: t("process_templates.adopted", name: source.name)
  end

  # A version of an acknowledgement item's PDF, to whoever reads the model, only once
  # clean (RN-06-060, P-05-30, D-640). The application serves it, so the bucket's
  # addresses never reach the browser (RN-01-014).
  def material
    authorize! :read, @template
    material = @template.items_with_materials.flat_map(&:materials).find { |version| version.id == params[:material_id] }
    raise ActiveRecord::RecordNotFound unless material&.clean?

    response.headers["Cache-Control"] = "private, no-store"
    send_data material.file.download, type: ProcessTemplateMaterialDefinition::CONTENT_TYPE, disposition: :inline,
      filename: material.file.filename.to_s
  end

  private

  # Out of the person's reach answers 404 (RN-03-006).
  def load_template
    @template = template_scope.accessible_by(current_ability, :read).find(params[:id])
  end

  def template_model
    template_scope.klass
  end

  def archived_redirect
    redirect_to template_route(:template, @template), alert: t("process_templates.archived_read_only")
  end

  def template_params(new_record:)
    permitted = %i[name description]
    permitted << :kind if new_record
    permitted << :onboarding_template_id if template_model == ProcessTemplate
    attributes = params.expect(process_template: permitted)
    attributes[:onboarding_template_id] = attributes[:onboarding_template_id].presence if attributes.key?(:onboarding_template_id)
    attributes
  end
end
