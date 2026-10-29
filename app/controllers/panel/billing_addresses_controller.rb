module Panel
  # The direct company's billing address, for its HR administrator (D-635). A partner's
  # company has no contract of its own (RN-19-001).
  class BillingAddressesController < BaseController
    include ClientBillingAddress

    before_action :require_current_company
    helper_method :billing_address_form_path, :billing_address_lookup_url, :billing_address_invoices_path

    private

    def billing_account_owner
      Current.company
    end

    def require_billing_feature
      head :not_found unless FeatureFlags.enabled?(FeatureFlags::BILLING)
    end

    def billing_address_form_path
      billing_address_path
    end

    def billing_address_lookup_url
      address_lookup_path(postal_code: "CEP")
    end

    def billing_address_invoices_path
      invoices_path
    end
  end
end
