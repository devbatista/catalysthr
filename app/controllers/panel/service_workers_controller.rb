module Panel
  # The PWA's service worker and the page without connection (spec 16, RN-16-061,
  # RN-16-062, D-424). The worker keeps only the app's shell: the files with a digest in
  # their names and this page, never a page or a piece of data. Both open before anyone
  # signs in, and carry nothing of the person.
  class ServiceWorkersController < BaseController
    skip_before_action :authenticate_user!, :require_legal_acceptance, :require_mfa_setup, :set_current_company,
      :require_sign_in_feature
    public_actions :show, :offline
    # A script served on purpose to the browser, the same as the assets.
    skip_forgery_protection only: :show

    # Changes when the assets or the worker change, so the browser installs the new one
    # and the page offers "Nova versão disponível" (RN-16-064).
    WORKER_REVISION = 1

    def show
      @version = Digest::SHA256.hexdigest([ WORKER_REVISION, helpers.stylesheet_path("tailwind"), helpers.stylesheet_path("application"),
        Rails.application.importmap.digest(resolver: helpers) ].join("/")).first(16)
      response.headers["Cache-Control"] = "no-cache"
      render template: "pwa/service-worker", formats: :js, content_type: "text/javascript", layout: false
    end

    def offline
      render layout: false
    end
  end
end
