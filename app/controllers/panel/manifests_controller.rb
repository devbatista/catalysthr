module Panel
  # PWA manifest of the subdomain's brand (RN-01-033, RN-01-036).
  class ManifestsController < BaseController
    # The browser fetches the manifest before anyone signs in.
    skip_before_action :authenticate_user!, :require_legal_acceptance, :require_sign_in_feature
    public_actions :show

    def show
      brand = Current.brand
      manifest = {
        name: brand.commercial_name,
        short_name: brand.app_name,
        lang: "pt-BR",
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
      large = brand.pwa_icon_large.attached? ? url_for(brand.pwa_icon_large) : "/icon.png"
      icons = [ { src: large, sizes: "512x512", type: "image/png" } ]
      icons << { src: url_for(brand.pwa_icon_small), sizes: "192x192", type: "image/png" } if brand.pwa_icon_small.attached?
      icons
    end
  end
end
