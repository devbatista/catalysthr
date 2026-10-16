module Panel
  # The brand's images, served by the application after checking who asks (RN-01-014):
  # the subdomain's brand is public, since the sign-in page and the installed app show
  # it before anyone signs in; a company's own brand only to who works in it. The bucket
  # stays private and its addresses never reach the browser.
  class BrandAssetsController < BaseController
    skip_before_action :authenticate_user!, :require_legal_acceptance, :require_mfa_setup, :set_current_company,
      :require_sign_in_feature, only: :show
    public_actions :show

    def show
      serve(Current.brand, public: true)
    end

    # The logo of the current company's own brand, in the panel's header (RN-01-034).
    def company
      authorize! :read, :panel_home
      serve(Current.company&.brand, public: false)
    end

    private

    def serve(brand, public:)
      kind = Brands::AttachImages::KINDS.find { |name| name.to_s == params[:kind] }
      attachment = brand && kind && brand.public_send(kind)
      raise ActiveRecord::RecordNotFound unless attachment&.attached?

      blob = attachment.blob
      expires_in 5.minutes, public: public
      return unless stale?(etag: blob.checksum, last_modified: blob.created_at, public: public)

      send_data blob.download, type: blob.content_type, disposition: :inline, filename: blob.filename.to_s
    end
  end
end
