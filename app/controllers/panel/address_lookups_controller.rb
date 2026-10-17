module Panel
  # Helpers of the unit's form: the address by CEP (D-215) and the suggested position
  # (D-216). Both answer JSON, and an empty answer lets the HR fill in by hand.
  class AddressLookupsController < BaseController
    before_action :require_current_company

    def show
      authorize! :lookup, :address
      result = Addresses::PostalCodeLookup.call(params[:postal_code])
      result ? render(json: result.to_h) : head(:not_found)
    end

    def geocode
      authorize! :lookup, :address
      result = Addresses::Geocoder.call(**params.permit(:street, :number, :city, :state, :postal_code).to_h.symbolize_keys
        .with_defaults(street: nil, number: nil, city: nil, state: nil, postal_code: nil))
      result ? render(json: result.to_h) : head(:not_found)
    end
  end
end
