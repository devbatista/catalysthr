module Panel
  module PartnerPanel
    # The partner's e-mail domain, by the partner's administrator (spec 01, section 6,
    # D-596).
    class BrandEmailDomainsController < BaseController
      include EmailDomainEditing

      before_action { @brand = partner.brand || raise(ActiveRecord::RecordNotFound) }

      private

      def brand_page_path
        edit_partner_brand_path
      end
    end
  end
end
