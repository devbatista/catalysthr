module Panel
  # The company's A1 certificate (spec 13, RN-13-020 to RN-13-022, D-075, D-673), by the HR
  # administrator: the current one with its holder and validity, the sending of a new one, which
  # replaces and erases the previous, and the removal. Sending and removing ask for the password
  # or a passkey again and are access events. The file and its password are never shown nor
  # downloaded. During an impersonate nothing is sent nor removed (RN-02-085).
  class EmployerCertificatesController < BaseController
    include SensitiveAccess

    before_action :require_current_company
    before_action -> { head :not_found unless FeatureFlags.enabled?(FeatureFlags::A1_CERTIFICATE) }

    # The page asks the password first, so the file chosen is not lost on the way (RN-02-052).
    def show
      authorize! :read, EmployerCertificate
      require_sensitive_confirmation
      return if performed?

      load_page
      @upload = Certificates::Upload.new(owner_kind: "employer")
    end

    def create
      authorize! :create, EmployerCertificate
      return redirect_to(employer_certificate_path, alert: t(".impersonating")) if impersonating?
      return require_confirmation unless sensitive_confirmed?

      @upload = Certificates::Upload.new(company: Current.company, by: current_user, file: params.dig(:certificate, :file),
        password: params.dig(:certificate, :pfx_password), owner_kind: params.dig(:certificate, :owner_kind))
      if @upload.save
        redirect_to employer_certificate_path, notice: t(".created")
      else
        load_page
        render :show, status: :unprocessable_content
      end
    end

    def destroy
      certificate = EmployerCertificate.active.first or raise ActiveRecord::RecordNotFound
      authorize! :destroy, certificate
      return redirect_to(employer_certificate_path, alert: t(".impersonating")) if impersonating?
      return require_confirmation unless sensitive_confirmed?

      Current.company.with_lock do
        certificate.retire!("removed", by: current_user)
        AccessEvent.record!(kind: "certificate", action: "certificate_removed", user: current_user, subject: certificate)
      end
      redirect_to employer_certificate_path, notice: t(".removed")
    end

    private

    def load_page
      @certificate = EmployerCertificate.active.includes(:uploaded_by).first
      @history = EmployerCertificate.where.not(status: "active").includes(:uploaded_by, :removed_by).order(created_at: :desc).limit(5)
    end

    def require_confirmation
      redirect_to new_sensitive_confirmation_path(return_to: employer_certificate_path), alert: t("panel.employer_certificates.confirm_first")
    end
  end
end
