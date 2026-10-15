# Pages of a brand's subdomain: the HR panel and the employee portal share the same
# address (D-155). HostResolver has already identified the brand, and
# ApplicationController has loaded it into Current.brand.
module Panel
  class BaseController < ApplicationController
    before_action :authenticate_user!
  end
end
