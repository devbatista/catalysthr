module Panel
  module Portal
    # The employee's folder in the portal (spec 08, RN-08-012, RN-08-013, RN-08-080,
    # RN-08-081; spec 16, D-645): the pending ones on top, the documents by category, only
    # the version in force and never the internal types (D-274, D-280), a sensitive file
    # only after the password (P-08-20), and the upload of a new document, with the camera
    # and the compression in the browser. The upload goes to the HR's review.
    class DocumentsController < BaseController
      include SensitiveAccess

      before_action :require_profile
      before_action :load_document, only: %i[show file]

      def index
        authorize! :read, :portal
        documents = folder.includes(:document_type, :dependent, versions: { pdf_attachment: :blob }).to_a
        @by_category = documents.group_by(&:category)
        @categories = DocumentCategory::ALL.select { |category| @by_category.key?(category) }
        @category = params[:category].presence_in(@categories)
        @documents = (@category ? @by_category[@category] : documents).sort_by { |document| document.document_type.name }
      end

      def show
        authorize! :read_own, @document
        @version = @document.current_version
        @latest = @document.latest_version
        @acknowledgments = @document.acknowledgments.where(worker_profile: current_profile).order(:created_at).to_a
      end

      # The version in force, the only one the employee sees (D-280); a sensitive one after
      # the password, each opening an access event (RN-08-081).
      def file
        authorize! :read_own, @document
        version = @document.current_version
        raise ActiveRecord::RecordNotFound unless version&.readable?
        if @document.sensitive?
          raise ActiveRecord::RecordNotFound if impersonating?
          unless sensitive_confirmed?
            return redirect_to new_sensitive_confirmation_path(return_to: portal_document_path(@document))
          end

          AccessEvent.record!(kind: "sensitive_read", action: "document_opened", user: current_user, subject: version,
            field: @document.category)
        end

        response.headers["Cache-Control"] = "private, no-store"
        send_data version.pdf.download, type: Documents::Upload::PDF, disposition: :inline, filename: "#{@document.document_type.name}.pdf"
      end

      def new
        authorize! :read, :portal
        @upload = Documents::Upload.new(worker_profile: current_profile, process_item: process_item,
          document_type: types.find { |type| type.id == (params[:document_type_id] || process_item&.config&.dig("document_type_id")) })
      end

      def create
        type = types.find { |each| each.id == params.dig(:upload, :document_type_id) }
        if type
          authorize! :upload_own, Document.new(company: Current.company, worker_profile: current_profile, document_type: type)
        else
          authorize! :read, :portal
        end
        @upload = Documents::Upload.new(worker_profile: current_profile, document_type: type, files: params.dig(:upload, :files),
          process_item: process_item, by: current_user, source: "employee")
        if @upload.save
          Documents::Notices.review_pending(@upload.document)
          redirect_to portal_document_path(@upload.document), notice: t(".created")
        else
          render :new, status: :unprocessable_content
        end
      end

      private

      def folder
        Document.for_employee.where(worker_profile: current_profile)
      end

      # Out of the person's reach answers 404 (RN-03-006).
      def load_document
        @document = folder.includes(:document_type).find(params[:id])
      end

      # The types the employee sends: in use, not internal and not health, which only the HR
      # and the clinic send (spec 03, section 4.5).
      def types
        @types ||= DocumentType.usable.where(internal: false).where.not(category: "health").ordered.to_a
      end
      helper_method :types

      # A process item waiting for this person's document (RN-06-010).
      def process_item
        id = params.dig(:upload, :process_item_id) || params[:process_item_id]
        @process_item ||= ProcessItem.accessible_by(current_ability, :complete_own).find(id) if id.present?
      end
    end
  end
end
