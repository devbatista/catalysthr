module Panel
  # The direct company's contracting during the trial or after it (RN-19-033, RN-19-034,
  # D-622), for its HR administrator. A partner's company has no contract of its own.
  class ContractsController < BaseController
    include ContractCheckout

    before_action :require_current_company
    before_action :require_billing_feature

    def new
      authorize! :contract, Current.company
      render_checkout(Current.company.billing_account)
    end

    def create
      authorize! :contract, Current.company
      start_checkout(Current.company.billing_account)
    end

    private

    def require_billing_feature
      head :not_found unless FeatureFlags.enabled?(FeatureFlags::BILLING)
    end

    def checkout_invoices_path
      invoices_path
    end

    def checkout_form_path
      contract_path
    end

    def checkout_invoice_path(invoice)
      invoice_path(invoice)
    end
  end
end
