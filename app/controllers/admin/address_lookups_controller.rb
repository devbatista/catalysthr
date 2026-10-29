module Admin
  # The address by CEP for the client's billing address (D-215, D-635), as in the panel's
  # unit form. JSON; an empty answer lets the team fill in by hand.
  class AddressLookupsController < BaseController
    def show
      authorize! :lookup, :address
      result = Addresses::PostalCodeLookup.call(params[:postal_code])
      result ? render(json: result.to_h) : head(:not_found)
    end
  end
end
