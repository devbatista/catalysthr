module Admin
  # The superadmin moves a company to another partner, or to and from the direct
  # modality, recording the company's authorization (RN-01-050 to RN-01-053, D-599).
  class CompanyTransfersController < BaseController
    DIRECT = "direct"

    before_action :require_company_transfer_feature

    def new
      authorize! :create, CompanyTransfer
      @query = params[:q].to_s.strip
      @companies = @query.length >= 3 ? search(@query) : Company.none
      @partners = Partner.includes(brand: :active_subdomain).order(:name)
    end

    def create
      authorize! :create, CompanyTransfer
      company = Company.find(params[:company_id])
      result = Companies::Transfer.call(company: company, to_partner: destination, performed_by: current_user,
        authorized_by_text: params[:authorized_by_text], document: params[:authorization_document], slug: params[:slug])

      if result.success?
        redirect_to new_admin_company_transfer_path, notice: t(".done", company: company.name, owner: owner_name(company.reload))
      else
        redirect_to new_admin_company_transfer_path(q: company.name), alert: result.errors.to_sentence
      end
    end

    private

    def require_company_transfer_feature
      head :not_found unless FeatureFlags.enabled?(FeatureFlags::COMPANY_TRANSFER)
    end

    def destination
      params[:to_partner_id] == DIRECT ? nil : Partner.find(params[:to_partner_id])
    end

    def owner_name(company)
      company.partner&.name || t("admin.company_transfers.new.direct")
    end

    def search(query)
      cnpj = Cnpj.normalize(query)
      by_name = Company.where("companies.name ILIKE ?", "%#{Company.sanitize_sql_like(query)}%")
      (cnpj.length == 14 ? by_name.or(Company.where(cnpj: cnpj)) : by_name).includes(:partner).order(:name).limit(20)
    end
  end
end
