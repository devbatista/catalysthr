# CatalystHR admin area, at the admin host (D-156). Only the CatalystHR team signs in
# here (RN-02-004, P-02-06).
module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
  end
end
