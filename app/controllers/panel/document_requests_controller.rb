module Panel
  # The HR's requests for a document (spec 08, RN-08-040, RN-08-041, D-278, D-643): the
  # type, one person or a group, the date and a message; each panel counts the answered,
  # in review, pending and late people (CA-08-005), only those of the viewer's scope.
  class DocumentRequestsController < BaseController
    include DocumentAudienceForm

    before_action :require_current_company

    def index
      authorize! :read, DocumentRequest
      @visible = visible_profile_ids.pluck(:id).to_set
      @requests = DocumentRequest.where(id: DocumentRequestTarget.where(worker_profile_id: visible_profile_ids).select(:document_request_id))
        .includes(:document_type, :requested_by, targets: { worker_profile: { employments: { revisions: :unit } } })
        .order(created_at: :desc).limit(50)
    end

    def new
      authorize! :create, DocumentRequest
      @form = Documents::RequestForm.new(audience_filter: audience_params, ability: current_ability,
        document_type: audience_types.find { |type| type.id == params[:document_type_id] })
    end

    def create
      authorize! :create, DocumentRequest
      @form = Documents::RequestForm.new(audience_filter: audience_params, ability: current_ability, by: current_user,
        document_type: audience_types.find { |type| type.id == params.dig(:request, :document_type_id) },
        due_on: parse_date(params.dig(:request, :due_on)), message: params.dig(:request, :message))
      if @form.save
        redirect_to document_request_path(@form.request), notice: t(".created", count: @form.people.size)
      else
        render :new, status: :unprocessable_content
      end
    end

    def show
      @request = DocumentRequest.includes(:document_type, :requested_by).find(params[:id])
      authorize! :read, @request
      @targets = @request.targets.where(worker_profile_id: visible_profile_ids)
        .includes(:document, worker_profile: [ :user, { employments: { revisions: :unit } } ]).to_a
        .sort_by { |target| target.worker_profile.display_name }
      raise ActiveRecord::RecordNotFound if @targets.empty?

      @counts = @request.counts(@targets)
    end

    private

    def parse_date(value)
      Date.iso8601(value.to_s) if value.present?
    rescue Date::Error
      nil
    end
  end
end
