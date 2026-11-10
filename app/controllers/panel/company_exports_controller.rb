module Panel
  # The company's full export (spec 18, RN-18-070 to RN-18-075, D-466, D-667), by the HR
  # administrator:
  # - asking needs the password or a passkey again and is recorded as an access event; at
  #   most one per week, counted from the last request that did not fail (RN-18-074,
  #   CA-18-012);
  # - only who asked opens it ready: the ZIP's password is shown once, with the password
  #   confirmed again, and erased (RN-18-075, D-667); each download of a part is an access
  #   event (RN-18-073);
  # - it is a copy of the company's data, so it is asked even in the contract's read only.
  # During an impersonate nothing is asked, the password is not shown and nothing is
  # downloaded (RN-02-085, RN-02-087).
  class CompanyExportsController < BaseController
    include SensitiveAccess
    include ActionController::Live

    before_action :require_current_company
    before_action -> { head :not_found unless FeatureFlags.enabled?(FeatureFlags::COMPANY_EXPORT) }
    writes_while_locked :create, :reveal_password

    def index
      authorize! :read, CompanyExport
      @exports = CompanyExport.where(kind: "full").includes(:requested_by).order(created_at: :desc).limit(20)
      @next_allowed_at = CompanyExport.next_allowed_at
    end

    def create
      authorize! :create, CompanyExport
      return redirect_to(new_sensitive_confirmation_path(return_to: company_exports_path)) unless impersonating? || sensitive_confirmed?
      return redirect_to(company_exports_path) if Simulation.active?

      export = nil
      Current.company.with_lock do
        if (allowed_at = CompanyExport.next_allowed_at)
          return redirect_to(company_exports_path, alert: t(".weekly_limit", date: l(allowed_at.in_time_zone.to_date)))
        end

        export = CompanyExport.create!(kind: "full", requested_by: current_user)
      end
      AccessEvent.record!(kind: "export", action: "company_export_requested", user: current_user, subject: export)
      Exports::CompanyJob.perform_later(export)
      redirect_to company_export_path(export), notice: t(".queued")
    end

    def show
      @export = CompanyExport.find(params[:id])
      authorize! :read, @export
    end

    # The ZIP's password, once, to who asked (RN-18-075, D-667).
    def reveal_password
      @export = CompanyExport.find(params[:id])
      authorize! :download, @export
      return redirect_to(company_export_path(@export)) if impersonating?
      return redirect_to(new_sensitive_confirmation_path(return_to: company_export_path(@export))) unless sensitive_confirmed?

      @password = @export.reveal_password!
      return redirect_to(company_export_path(@export)) unless @password

      AccessEvent.record!(kind: "sensitive_read", action: "company_export_password_shown", user: current_user, subject: @export)
      response.headers["Cache-Control"] = "private, no-store"
      render :show
    end

    def download
      @export = CompanyExport.find(params[:id])
      authorize! :download, @export
      raise ActiveRecord::RecordNotFound if impersonating? || !@export.available?
      return redirect_to(new_sensitive_confirmation_path(return_to: company_export_path(@export))) unless sensitive_confirmed?

      part = @export.parts.find(params[:part_id])
      AccessEvent.record!(kind: "download", action: "company_export_downloaded", user: current_user, subject: @export,
        metadata: { part: part.filename.to_s })
      response.headers["Cache-Control"] = "private, no-store"
      send_stream(filename: part.filename.to_s, type: "application/zip") do |stream|
        part.download { |chunk| stream.write(chunk) }
      end
    end
  end
end
