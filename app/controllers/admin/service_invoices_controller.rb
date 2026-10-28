module Admin
  # "Emitir de novo" (RN-19-108, D-563): the finance team or the superadmin sends again a
  # note refused by Asaas or the city, after fixing what was wrong.
  class ServiceInvoicesController < BillingController
    before_action :require_nfse_feature

    def reissue
      invoice = Invoice.find(params[:invoice_id])
      note = invoice.service_invoice || raise(ActiveRecord::RecordNotFound)
      authorize! :reissue, note

      if Billing::ServiceInvoices.reissue(note)
        redirect_to admin_invoice_path(invoice), notice: t(".sent")
      else
        redirect_to admin_invoice_path(invoice), alert: t(".not_in_error")
      end
    end

    private

    def require_nfse_feature
      head :not_found unless FeatureFlags.enabled?(FeatureFlags::NFSE)
    end
  end
end
