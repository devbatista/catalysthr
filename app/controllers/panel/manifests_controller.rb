module Panel
  # PWA manifest of the subdomain's brand (RN-01-033, RN-01-036).
  class ManifestsController < BaseController
    # The browser fetches the manifest before anyone signs in.
    skip_before_action :authenticate_user!, :require_legal_acceptance, :require_mfa_setup, :set_current_company,
      :require_sign_in_feature
    public_actions :show

    def show
      brand = Current.brand
      manifest = {
        name: brand.commercial_name,
        short_name: brand.app_name,
        lang: "pt-BR",
        # "/" sends each person to the portal or the panel by profile (RN-16-002, D-646).
        id: "/",
        start_url: "/",
        scope: "/",
        display: "standalone",
        theme_color: brand.colors[:primary],
        background_color: "#FFFFFF",
        icons: icons(brand)
      }

      render json: manifest, content_type: "application/manifest+json"
    end

    private

    def icons(brand)
      icons = [ icon(brand, :pwa_icon_large, "512x512") || { src: "/icon.png", sizes: "512x512", type: "image/png" } ]
      icons << icon(brand, :pwa_icon_small, "192x192")
      icons.compact
    end

    def icon(brand, kind, sizes)
      attachment = brand.public_send(kind)
      return unless attachment.attached?

      { src: helpers.brand_image_path(brand, kind), sizes: sizes, type: attachment.blob.content_type }
    end
  end
end
