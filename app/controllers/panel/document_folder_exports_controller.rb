module Panel
  # A person's folder in ZIP (spec 08, RN-08-082, D-281, P-08-21, D-644): asked with the
  # password and recorded as an access event, made in a job with what the person who asks
  # may read, and served only to them, for 24 hours, without exposing the bucket. The
  # download streams the file, so a large folder does not sit in memory.
  class DocumentFolderExportsController < BaseController
    include SensitiveAccess
    include ActionController::Live

    before_action :require_current_company

    def create
      profile = WorkerProfile.accessible_by(current_ability, :read).find(params[:employee_id])
      authorize! :export, profile
      # A POST cannot come back after the password, so it returns to the folder.
      unless impersonating? || sensitive_confirmed?
        return redirect_to new_sensitive_confirmation_path(return_to: employee_documents_path(profile))
      end

      export = DocumentFolderExport.create!(worker_profile: profile, requested_by: current_user)
      AccessEvent.record!(kind: "export", action: "document_folder_requested", user: current_user, subject: profile)
      Documents::ZipFolderJob.perform_later(export)
      redirect_to employee_documents_path(profile), notice: t(".queued")
    end

    def download
      export = DocumentFolderExport.find(params[:id])
      authorize! :download, export
      raise ActiveRecord::RecordNotFound unless export.available?

      AccessEvent.record!(kind: "download", action: "document_folder_downloaded", user: current_user, subject: export.worker_profile)
      response.headers["Cache-Control"] = "private, no-store"
      send_stream(filename: export.zip.filename.to_s, type: "application/zip") do |stream|
        export.zip.download { |chunk| stream.write(chunk) }
      end
    end
  end
end
