module Panel
  module PartnerPanel
    # The partner's panel (spec 03, section 4.1), on the partner's subdomain. It has no
    # current company (RN-01-004): companies are reached only through the person's
    # portfolio (RN-01-011).
    class BaseController < Panel::BaseController
      skip_before_action :set_current_company

      private

      # The partner that owns the subdomain. Any other subdomain has no partner's panel.
      def partner
        owner = Current.brand.owner
        owner.is_a?(Partner) ? owner : raise(ActiveRecord::RecordNotFound)
      end
    end
  end
end
