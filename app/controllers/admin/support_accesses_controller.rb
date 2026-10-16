module Admin
  # The support enters a direct company to set it up or to help (D-581): find the
  # company, give the reason or ticket number, and open its subdomain with a one-time
  # token. In a partner's company the support only sees by impersonate (P-03-02).
  class SupportAccessesController < BaseController
    def new
      authorize! :create, SupportAccess
      @query = params[:q].to_s.strip
      @companies = @query.length >= 3 ? search(@query) : Company.none
    end

    def create
      authorize! :create, SupportAccess
      company = Company.find(params[:company_id])
      access, token = SupportAccess.issue!(support_user: current_user, company: company, reason: params[:reason].to_s.strip)
      redirect_to access.brand.panel_url("/support-access", token: token), allow_other_host: true
    rescue ActiveRecord::RecordInvalid => error
      redirect_to new_admin_support_access_path(q: company&.name), alert: error.record.errors.full_messages.to_sentence
    end

    private

    def search(query)
      cnpj = Cnpj.normalize(query)
      companies = Company.where(partner_id: nil)
      by_name = companies.where("companies.name ILIKE ?", "%#{Company.sanitize_sql_like(query)}%")
      (cnpj.length == 14 ? by_name.or(companies.where(cnpj: cnpj)) : by_name).order(:name).limit(20)
    end
  end
end
