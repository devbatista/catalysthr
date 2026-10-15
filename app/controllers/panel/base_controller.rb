# Pages of a brand's subdomain: the HR panel and the employee portal share the same
# address (D-155). HostResolver has already identified the brand.
module Panel
  class BaseController < ApplicationController
    layout "panel"

    before_action :set_brand

    private

    def set_brand
      Current.brand = Brand.find(request.env.fetch(HostResolver::BRAND_ID))
    end
  end
end
