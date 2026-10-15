module Panel
  # Entry page after sign-in (RN-01-004). The partner's and the accounting firm's teams
  # start at their own area; with more than one company, the person chooses one first.
  class HomeController < BaseController
    def index
      authorize! :read, :panel_home
      return if Current.company

      if partner_membership
        redirect_to partner_root_path
      elsif firm_membership
        redirect_to firm_root_path
      elsif authorized_companies.many?
        redirect_to companies_path
      end
    end
  end
end
