module Panel
  # The direct company's cancellation and its undo (RN-19-062, D-625), for its HR
  # administrator. A partner's company has no contract of its own.
  class CancellationsController < BaseController
    include ContractCancellation

    # Undoing stays open while the contract is read only (D-624, D-625).
    writes_while_locked :destroy

    before_action :require_current_company
    before_action :require_billing_feature

    def show
      authorize! :cancel_contract, Current.company
      show_cancellation(Current.company.billing_account)
    end

    def create
      authorize! :cancel_contract, Current.company
      create_cancellation(Current.company.billing_account)
    end

    def destroy
      authorize! :cancel_contract, Current.company
      destroy_cancellation(Current.company.billing_account)
    end

    private

    def require_billing_feature
      head :not_found unless FeatureFlags.enabled?(FeatureFlags::BILLING)
    end

    def cancellation_form_path
      cancellation_path
    end

    def cancellation_invoices_path
      invoices_path
    end
  end
end
