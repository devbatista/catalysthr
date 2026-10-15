module Panel
  module FirmPanel
    # The accounting firm's area (spec 02, RN-02-070 to RN-02-073), on the subdomain of a
    # brand whose companies the firm serves. It has no current company and shows only
    # this brand's companies, so a partner never sees another's clients (D-586).
    class BaseController < Panel::BaseController
      skip_before_action :set_current_company

      private

      def firm
        firm_membership&.organization || raise(ActiveRecord::RecordNotFound)
      end

      def brand_links
        firm.accounting_firm_companies.where(company_id: Current.brand.served_companies.select(:id))
      end
    end
  end
end
