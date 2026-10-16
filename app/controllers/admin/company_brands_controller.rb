module Admin
  # A partner's client company's own brand and display mode, edited by the superadmin
  # and the support (RN-01-034, spec 01, section 6).
  class CompanyBrandsController < BaseController
    include BrandEditing

    before_action do
      @company = Company.where.not(partner_id: nil).find(params[:company_id])
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
        redirect_to edit_admin_company_brand_path(@company), notice: t("brands.updated")
      else
        render :edit, status: :unprocessable_content
      end
    end
  end
end
