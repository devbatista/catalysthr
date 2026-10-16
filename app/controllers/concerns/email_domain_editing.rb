# Registering and removing a brand's e-mail domain (RN-01-040, D-596). The including
# controller loads @brand and tells where the brand's page is.
module EmailDomainEditing
  extend ActiveSupport::Concern

  included do
    before_action :require_email_domain_feature
  end

  def create
    authorize! :manage_email_domain, @brand
    Brands::RegisterEmailDomain.call(brand: @brand, domain: params[:email_domain].to_s, user: current_user)
    if @brand.errors.empty?
      redirect_to brand_page_path, notice: t("brands.email_domain.registered")
    else
      redirect_to brand_page_path, alert: @brand.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize! :manage_email_domain, @brand
    if Brands::RemoveEmailDomain.call(brand: @brand)
      redirect_to brand_page_path, notice: t("brands.email_domain.removed")
    else
      redirect_to brand_page_path, alert: t("activerecord.errors.models.brand.attributes.base.ses_unavailable")
    end
  end

  private

  def require_email_domain_feature
    head :not_found unless FeatureFlags.enabled?(FeatureFlags::BRAND_EMAIL_DOMAIN)
  end
end
