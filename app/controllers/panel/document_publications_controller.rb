module Panel
  # The publications asking for an acknowledgment (spec 08, RN-08-050 to RN-08-054, D-279,
  # D-643): the PDF, one person or a group and the date; each panel shows who confirmed,
  # who is waiting and who refused, only the people of the viewer's scope. The refusal
  # comes after the date, with a note and up to two witnesses. The receipt carries the
  # witnesses' CPFs and the IPs, so it asks for the password and is an access event.
  class DocumentPublicationsController < BaseController
    include DocumentAudienceForm
    include SensitiveAccess

    before_action :require_current_company
    before_action :load_publication, only: %i[show receipt refuse]

    def index
      authorize! :read, DocumentPublication
      @visible = visible_profile_ids.pluck(:id).to_set
      @publications = DocumentPublication.where(id: Acknowledgment.where(worker_profile_id: visible_profile_ids).select(:document_publication_id))
        .includes(:document_type, :published_by, acknowledgments: { worker_profile: { employments: { revisions: :unit } } })
        .order(created_at: :desc).limit(50)
    end

    def new
      authorize! :create, DocumentPublication
      @form = Documents::Publish.new(audience_filter: audience_params, ability: current_ability,
        document_type: audience_types.find { |type| type.id == params[:document_type_id] })
    end

    def create
      authorize! :create, DocumentPublication
      attributes = params.fetch(:publication, {})
      @form = Documents::Publish.new(audience_filter: audience_params, ability: current_ability, by: current_user,
        document_type: audience_types.find { |type| type.id == attributes[:document_type_id] }, title: attributes[:title],
        file: attributes[:file], due_on: parse_date(attributes[:due_on]), message: attributes[:message])
      if @form.save
        redirect_to document_publication_path(@form.publication), notice: t(".created", count: @form.people.size)
      else
        render :new, status: :unprocessable_content
      end
    end

    def show
      authorize! :read, @publication
    end

    # The receipt of every record of the viewer's scope (RN-08-054, P-08-15).
    def receipt
      authorize! :read, @publication
      require_sensitive_confirmation
      return if performed?

      AccessEvent.record!(kind: "download", action: "acknowledgment_receipt", user: current_user, subject: @publication)
      response.headers["Cache-Control"] = "private, no-store"
      send_data Documents::AcknowledgmentReceipt.new(@publication, @acknowledgments).render, type: Documents::Upload::PDF,
        disposition: :attachment, filename: "ciencia-#{@publication.created_at.to_date.iso8601}.pdf"
    end

    # The refusal after the date (RN-08-053, P-08-14).
    def refuse
      acknowledgment = @acknowledgments.find { |each| each.id == params[:acknowledgment_id] } or raise ActiveRecord::RecordNotFound
      authorize! :refuse, acknowledgment
      witnesses = Acknowledgment::MAX_WITNESSES.times.filter_map { |index| params.dig(:witnesses, index.to_s)&.permit(:name, :cpf)&.to_h }
      if Documents::Acknowledge.new(acknowledgment).refuse(by: current_user, note: params[:refused_note], witnesses: witnesses)
        redirect_to document_publication_path(@publication), notice: t(".refused", name: acknowledgment.worker_profile.display_name)
      else
        redirect_to document_publication_path(@publication), alert: acknowledgment.errors.full_messages.to_sentence
      end
    end

    private

    # Out of the viewer's scope answers 404 (RN-03-006).
    def load_publication
      @publication = DocumentPublication.includes(:document_type, :published_by).find(params[:id])
      @acknowledgments = @publication.acknowledgments.where(worker_profile_id: visible_profile_ids)
        .includes(:version, :recorded_by, worker_profile: [ :user, { employments: { revisions: :unit } } ]).to_a
        .sort_by { |acknowledgment| acknowledgment.worker_profile.display_name }
      raise ActiveRecord::RecordNotFound if @acknowledgments.empty?
    end

    def parse_date(value)
      Date.iso8601(value.to_s) if value.present?
    rescue Date::Error
      nil
    end
  end
end
