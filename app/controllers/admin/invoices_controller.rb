module Admin
  # The invoices of every contract (RN-19-080, D-619), most recent first. The superadmin and
  # the finance team read them, and the support too (spec 19, section 6). Payments, voiding
  # and adjustments come with the next blocks.
  class InvoicesController < BillingController
    include ServiceInvoiceFiles

    LIMIT = 100

    def index
      authorize! :read, Invoice
      @invoices = Invoice.includes(billing_account: :owner).recent_first.limit(LIMIT)
    end

    def show
      @invoice = Invoice.includes(:lines, billing_account: :owner).find(params[:id])
      authorize! :read, @invoice
    end

    # The NFS-e's PDF or XML (RN-19-107).
    def service_invoice_file
      invoice = Invoice.find(params[:id])
      authorize! :read, invoice
      send_service_invoice_file(invoice)
    end
  end
end
