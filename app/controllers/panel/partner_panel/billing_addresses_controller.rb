module Panel
  module PartnerPanel
    # The partner's billing address, for its administrator (D-635).
    class BillingAddressesController < BaseController
      include ClientBillingAddress

      helper_method :billing_address_form_path, :billing_address_lookup_url, :billing_address_invoices_path

      private

      def billing_account_owner
        partner
      end

      def billing_address_form_path
        partner_billing_address_path
      end

      def billing_address_lookup_url
        partner_address_lookup_path(postal_code: "CEP")
      end

      def billing_address_invoices_path
        partner_invoices_path
      end
    end
  end
end
