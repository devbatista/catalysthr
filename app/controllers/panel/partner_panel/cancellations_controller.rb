module Panel
  module PartnerPanel
    # The partner's cancellation and its undo (RN-19-062, RN-19-063, D-625), for its
    # administrator.
    class CancellationsController < BaseController
      include ContractCancellation

      # Undoing stays open while the contract is read only (D-624, D-625).
      writes_while_locked :destroy

      before_action :require_billing_feature

      def show
        authorize! :cancel_contract, partner
        show_cancellation(partner.billing_account)
      end

      def create
        authorize! :cancel_contract, partner
        create_cancellation(partner.billing_account)
      end

      def destroy
        authorize! :cancel_contract, partner
        destroy_cancellation(partner.billing_account)
      end

      private

      def cancellation_form_path
        partner_cancellation_path
      end

      def cancellation_invoices_path
        partner_invoices_path
      end
    end
  end
end
