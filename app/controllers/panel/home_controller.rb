module Panel
  # Entry page after sign-in. The initial area and the current company come with
  # spec 01, part 2 (RN-01-004).
  class HomeController < BaseController
    def index
      authorize! :read, :panel_home
    end
  end
end
