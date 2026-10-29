module Panel
  module PartnerPanel
    # The address by CEP for the partner's billing address (D-215, D-635). JSON; an empty
    # answer lets the partner fill in by hand.
    class AddressLookupsController < BaseController
      def show
        authorize! :lookup, :address
        result = Addresses::PostalCodeLookup.call(params[:postal_code])
        result ? render(json: result.to_h) : head(:not_found)
      end
    end
  end
end
