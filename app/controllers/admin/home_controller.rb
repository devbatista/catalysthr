module Admin
  # Entry page of the admin area. The admin screens come with spec 19.
  class HomeController < BaseController
    def index
      authorize! :read, :admin_home
    end
  end
end
