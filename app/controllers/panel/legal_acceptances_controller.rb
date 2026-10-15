module Panel
  # Terms of use and privacy policy of the brand: accepted in the first access and
  # again after every new version (RN-02-014, item 2; RN-02-015; RN-02-017).
  class LegalAcceptancesController < BaseController
    layout "auth"

    skip_before_action :require_legal_acceptance, :require_mfa_setup

    before_action :load_acceptance

    def show
      authorize! :accept, :legal_documents
      redirect_to root_path unless @acceptance.pending?
    end

    def create
      authorize! :accept, :legal_documents
      unless all_accepted?
        @error = t(".must_accept")
        return render(:show, status: :unprocessable_content)
      end

      @acceptance.accept!(ip: request.remote_ip, user_agent: request.user_agent)
      redirect_to root_path
    end

    private

    def load_acceptance
      @acceptance = LegalAcceptance.new(current_user, Current.brand)
    end

    def all_accepted?
      @acceptance.published? && @acceptance.pending.all? { |document| params.dig(:accept, document.kind) == "1" }
    end
  end
end
