# Pages of a brand's subdomain: the HR panel and the employee portal share the same
# address (D-155). HostResolver has already identified the brand, and
# ApplicationController has loaded it into Current.brand.
module Panel
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_legal_acceptance

    private

    # Nothing else opens until the terms and the policy in force are accepted
    # (RN-02-014, RN-02-017).
    def require_legal_acceptance
      redirect_to legal_acceptance_path if LegalAcceptance.new(current_user, Current.brand).pending?
    end
  end
end
