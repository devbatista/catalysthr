module Admin
  # The e-mail domain of a partner's or a direct company's brand, by the superadmin and
  # the support (spec 01, section 6, D-596).
  class BrandEmailDomainsController < BaseController
    include EmailDomainEditing

    before_action do
      @brand = Brand.find(params[:brand_id])
      raise ActiveRecord::RecordNotFound unless @brand.email_domain_configurable?
    end

    private

    def brand_page_path
      edit_admin_brand_path(@brand)
    end
  end
end
