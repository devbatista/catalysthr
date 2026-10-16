module Admin
  # Brands of partners and direct companies, edited by the superadmin and the support;
  # only the superadmin changes the slug (spec 01, section 6, P-01-17, RN-01-022). Every
  # change stays in the trail (spec 05).
  class BrandsController < BaseController
    include BrandEditing

    before_action :load_brand, except: :index

    def index
      authorize! :read, Brand
      @query = params[:q].to_s.strip
      @brands = Brand.includes(:owner, :active_subdomain).order(:commercial_name)
      @brands = @brands.where("brands.commercial_name ILIKE ?", "%#{Brand.sanitize_sql_like(@query)}%") if @query.present?
      @brands = @brands.select(&:owns_subdomain?).first(100)
    end

    def edit
      authorize! :update, @brand
    end

    def update
      authorize! :update, @brand
      if @brand.update(brand_params)
        redirect_to edit_admin_brand_path(@brand), notice: t("brands.updated")
      else
        render :edit, status: :unprocessable_content
      end
    end

    def slug
      authorize! :change_slug, @brand
      Brands::ChangeSlug.call(brand: @brand, slug: params[:slug])
      redirect_to edit_admin_brand_path(@brand), notice: t(".changed")
    rescue ActiveRecord::RecordInvalid => error
      redirect_to edit_admin_brand_path(@brand), alert: error.record.errors.full_messages.to_sentence
    end

    private

    def load_brand
      @brand = Brand.find(params[:id])
      raise ActiveRecord::RecordNotFound unless @brand.owns_subdomain?
    end
  end
end
