# The person's own security pages, at the admin host and on every brand's subdomain.
# They open before the terms and the MFA steps, because the MFA setup is one of them.
module Account
  class BaseController < ApplicationController
    before_action :authenticate_user!
    # The MFA secret and the recovery codes must not stay in any cache.
    before_action { response.headers["Cache-Control"] = "no-store" }

    private

    # Sensitive changes ask for the current password again.
    def current_password_valid?
      current_user.valid_password?(params[:current_password].to_s)
    end
  end
end
