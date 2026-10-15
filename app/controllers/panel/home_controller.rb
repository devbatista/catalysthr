module Panel
  # Entry page after sign-in. With more than one company, the person chooses one first
  # (RN-01-004). The partner's panel comes with block 4b.
  class HomeController < BaseController
    def index
      authorize! :read, :panel_home
      redirect_to companies_path if Current.company.nil? && authorized_companies.many?
    end
  end
end
