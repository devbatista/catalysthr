module Panel
  # The direct company's invoices, for its HR administrator, the financial responsible
  # (RN-19-044, D-619). A partner's company has no contract of its own (RN-19-001).
  class InvoicesController < BaseController
    include InvoicePix
    include ServiceInvoiceFiles

    before_action :require_current_company
    before_action :require_billing_feature

    def index
      authorize! :read_invoices, Current.company
      @invoices = invoices.recent_first
    end

    def show
      authorize! :read_invoices, Current.company
      @invoice = invoices.includes(:lines).find(params[:id])
      load_pix(@invoice)
    end

    # The NFS-e's PDF or XML (RN-19-107).
    def service_invoice_file
      authorize! :read_invoices, Current.company
      send_service_invoice_file(invoices.find(params[:id]))
    end

    private

    def require_billing_feature
      head :not_found unless FeatureFlags.enabled?(FeatureFlags::BILLING)
    end

    def invoices
      Current.company.billing_account&.invoices || Invoice.none
    end
  end
end
