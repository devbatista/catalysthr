module Panel
  module PartnerPanel
    # The partner's contracting during the trial or after it (RN-19-033, RN-19-034, D-622),
    # for its administrator.
    class ContractsController < BaseController
      # Open while the contract is read only (D-624).
      writes_while_locked :create

      include ContractCheckout

      before_action :require_billing_feature

      def new
        authorize! :contract, partner
        render_checkout(partner.billing_account)
      end

      def create
        authorize! :contract, partner
        start_checkout(partner.billing_account)
      end

      private

      def checkout_invoices_path
        partner_invoices_path
      end

      def checkout_form_path
        partner_contract_path
      end

      def checkout_invoice_path(invoice)
        partner_invoice_path(invoice)
      end
    end
  end
end
