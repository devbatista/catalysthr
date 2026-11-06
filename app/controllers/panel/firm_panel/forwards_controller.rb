module Panel
  module FirmPanel
    # What the HR forwarded to the firm (RN-06-065, RN-07-070, D-143, D-651, D-652): the list,
    # the record without health and the validated documents, after the password, and
    # "Confirmar recebimento". Each forward is read inside its company, so the access events
    # stay with it. Anything out of the firm's reach answers 404 (RN-03-006).
    class ForwardsController < BaseController
      include SensitiveAccess

      SECTIONS = %w[documents pay].freeze

      content_security_policy only: :document do |policy|
        policy.frame_ancestors :self
      end

      before_action :require_admissions_feature
      around_action :inside_company, except: :index

      def index
        authorize! :read, :firm_forwards
        @rows = Processes::FirmForward.rows(firm, linked_companies)
      end

      def show
        authorize! :read, :firm_forwards
        reveal_all_sections(SECTIONS)
        return if performed?

        @instance = @item.instance
        @employment = @instance.employment
        @profile = @employment.worker_profile
        @documents = Processes::FirmForward.documents(@item).includes(:document_type, :current_version).to_a
        AccessEvent.record!(kind: "sensitive_read", action: "firm_forward_opened", user: current_user, subject: @item)
      end

      def confirm
        authorize! :confirm_receipt, :firm_forwards
        if Processes::ItemActions.new(@item, by: current_user).confirm_receipt
          redirect_to firm_forward_path(@item), notice: t(".confirmed")
        else
          redirect_to firm_forward_path(@item), alert: @item.errors.full_messages.to_sentence
        end
      end

      # Only after the password, never during an impersonate, and each opening is an access
      # event (RN-08-081, D-651). The application serves it, so the bucket's addresses never
      # reach the browser (RN-01-014).
      def document
        authorize! :read, :firm_forwards
        raise ActiveRecord::RecordNotFound if impersonating? || !sensitive_confirmed?

        document = Processes::FirmForward.documents(@item).find(params[:document_id])
        version = document.current_version
        raise ActiveRecord::RecordNotFound unless version&.readable?

        AccessEvent.record!(kind: "sensitive_read", action: "document_opened", user: current_user, subject: version, field: document.category)
        response.headers["Cache-Control"] = "private, no-store"
        send_data version.pdf.download, type: Documents::Upload::PDF, disposition: :inline,
          filename: "#{document.document_type.name}-v#{version.number}.pdf"
      end

      private

      def require_admissions_feature
        head :not_found unless FeatureFlags.enabled?(FeatureFlags::ADMISSIONS)
      end

      # The brand's companies with an active link (RN-02-073, D-586).
      def linked_companies
        @linked_companies ||= Company.where(id: brand_links.active.select(:company_id)).to_a
      end

      def inside_company
        @item = Processes::FirmForward.find(firm, linked_companies, params[:id])
        Current.company = @item.company
        ActsAsTenant.with_tenant(@item.company) { yield }
      end
    end
  end
end
