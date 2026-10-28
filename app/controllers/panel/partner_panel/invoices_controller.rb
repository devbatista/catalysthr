module Panel
  module PartnerPanel
    # The partner contract's invoices, for the partner's administrator, its financial
    # responsible (RN-19-044, D-619).
    class InvoicesController < BaseController
      include InvoicePix
      include ServiceInvoiceFiles

      before_action :require_billing_feature

      def index
        authorize! :read_invoices, partner
        @invoices = invoices.recent_first
      end

      def show
        authorize! :read_invoices, partner
        @invoice = invoices.includes(:lines).find(params[:id])
        load_pix(@invoice)
      end

      # The NFS-e's PDF or XML (RN-19-107).
      def service_invoice_file
        authorize! :read_invoices, partner
        send_service_invoice_file(invoices.find(params[:id]))
      end

      private

      # Only the partner's own contract; any other invoice is not found.
      def invoices
        partner.billing_account&.invoices || Invoice.none
      end
    end
  end
end
