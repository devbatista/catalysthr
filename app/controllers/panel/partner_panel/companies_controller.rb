module Panel
  module PartnerPanel
    # The partner's administrator registers a client company in the portfolio, with the
    # contracted modules it uses and its first HR administrator (P-03-14, RN-19-012,
    # D-616).
    class CompaniesController < BaseController
      before_action :require_billing_feature

      def new
        authorize! :create, Company.new(partner: partner)
        @registration = Billing::PortfolioCompanyRegistration.new(partner: partner)
        @registration.modules = @registration.contracted_modules
      end

      def create
        authorize! :create, Company.new(partner: partner)
        @registration = Billing::PortfolioCompanyRegistration.new(registration_params.merge(partner: partner))
        if @registration.save(by: current_user)
          notice = @registration.existing_person? ? ".created_existing_person" : ".created"
          redirect_to partner_root_path, notice: t(notice, company: @registration.company.name, email: @registration.admin_email)
        else
          render :new, status: :unprocessable_content
        end
      end

      private

      def registration_params
        params.expect(company: [ :legal_name, :commercial_name, :cnpj, :admin_name, :admin_cpf, :admin_email, modules: [] ])
      end
    end
  end
end
