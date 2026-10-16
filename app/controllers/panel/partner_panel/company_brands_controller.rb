module Panel
  module PartnerPanel
    # A client company's own brand and its display mode, edited by the partner's
    # administrator (RN-01-034, D-163, D-165, D-166).
    class CompanyBrandsController < BaseController
      include BrandEditing

      before_action do
        @company = (partner_membership&.portfolio_companies || Company.none).find(params[:company_id])
        @brand = @company.brand || @company.build_brand(commercial_name: @company.name)
      end

      def edit
        authorize! (@brand.new_record? ? :create : :update), @brand
      end

      def update
        authorize! (@brand.new_record? ? :create : :update), @brand
        @brand = Brands::UpdateCompanyBrand.call(company: @company, attributes: company_brand_params,
          display_mode: display_mode_param(@company))
        if @brand.errors.empty?
          redirect_to edit_partner_company_brand_path(@company), notice: t("brands.updated")
        else
          render :edit, status: :unprocessable_content
        end
      end
    end
  end
end
