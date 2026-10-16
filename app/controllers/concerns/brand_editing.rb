# Editing a brand that owns a subdomain: a partner's or a direct company's (RN-01-030).
# The images come with the S3 (spec 01, block 2b).
module BrandEditing
  FIELDS = %i[commercial_name short_name primary_color secondary_color accent_color login_welcome_text
    support_email support_phone].freeze

  private

  def brand_params
    params.require(:brand).permit(*FIELDS).to_h.transform_values(&:presence)
  end

  def company_brand_params
    params.fetch(:brand, {}).permit(*Brands::UpdateCompanyBrand::ATTRIBUTES)
  end

  # The mode is saved only by who may choose it (D-165).
  def display_mode_param(company)
    mode = params[:brand_display_mode].presence
    return if mode.nil?

    authorize! :update_brand_display_mode, company
    mode
  end
end
