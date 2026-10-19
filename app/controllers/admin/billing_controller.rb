module Admin
  # Base of the admin's billing screens (spec 19), hidden until the launch (D-610).
  class BillingController < BaseController
    before_action :require_billing_feature

    private

    def require_billing_feature
      head :not_found unless FeatureFlags.enabled?(FeatureFlags::BILLING)
    end
  end
end
