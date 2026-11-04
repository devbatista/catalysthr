module Panel
  module Portal
    # A new version of the employee's own document (RN-08-013, RN-08-022, RN-08-023): the
    # one the HR asked, the correction or the renewal, with the camera and the compression
    # in the browser (RN-08-012). It goes to the HR's review.
    class DocumentVersionsController < BaseController
      before_action :require_profile
      before_action :load_document

      def new
        authorize! :upload_own, @document
        @upload = Documents::Upload.new(document: @document, worker_profile: current_profile)
      end

      def create
        authorize! :upload_own, @document
        @upload = Documents::Upload.new(document: @document, worker_profile: current_profile, files: params.dig(:upload, :files),
          by: current_user)
        if @upload.save
          Documents::Notices.review_pending(@document)
          redirect_to portal_document_path(@document), notice: t(".created")
        else
          render :new, status: :unprocessable_content
        end
      end

      private

      # Out of the person's reach answers 404 (RN-03-006). A document the HR published asking
      # for the acknowledgment takes no version from the employee (D-643).
      def load_document
        @document = Document.for_employee.where(worker_profile: current_profile)
          .where("documents.source_ref_type IS DISTINCT FROM ?", "DocumentPublication").includes(:document_type).find(params[:document_id])
      end
    end
  end
end
