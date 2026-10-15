module Admin
  # The CatalystHR terms of use and privacy policy, used by brands without their own
  # (D-578). The superadmin publishes new versions; published ones never change (D-579).
  class LegalDocumentsController < BaseController
    def index
      authorize! :read, LegalDocument
      @documents = LegalDocument.platform.accessible_by(current_ability).order(:kind, version: :desc)
    end

    def new
      @document = LegalDocument.platform.new(kind: params[:kind])
      authorize! :create, @document
    end

    def create
      @document = LegalDocument.platform.new(params.expect(legal_document: [ :kind, :body ]))
      @document.published_by = current_user
      authorize! :create, @document

      if @document.save
        redirect_to admin_legal_documents_path, notice: t(".published", version: @document.version)
      else
        render :new, status: :unprocessable_content
      end
    end
  end
end
