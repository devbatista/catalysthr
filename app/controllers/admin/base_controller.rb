# CatalystHR admin area, at the admin host (D-156). Only the CatalystHR team signs in
# here (RN-02-004, P-02-06).
module Admin
  class BaseController < ApplicationController
    layout "admin_app"

    before_action :authenticate_user!
    before_action :require_mfa_setup
  end
end
