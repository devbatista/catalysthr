module Panel
  # A document's versions (spec 08, D-642): the HR's upload of a new one (RN-08-013), its
  # PDF (RN-08-081) and the review (RN-08-021 to RN-08-023). The PDF opens beside the
  # review, so only this response may be framed, and only by the application's own pages.
  class DocumentVersionsController < BaseController
    include SensitiveAccess

    before_action :require_current_company
    before_action :load_document
    before_action :load_version, only: %i[file approve correction reprocess]

    content_security_policy only: :file do |policy|
      policy.frame_ancestors :self
    end

    def new
      authorize! :upload, @document
      @upload = Documents::Upload.new(document: @document, worker_profile: @document.worker_profile)
    end

    def create
      authorize! :upload, @document
      @upload = Documents::Upload.new(document: @document, worker_profile: @document.worker_profile, by: current_user,
        files: params.dig(:upload, :files))
      if @upload.save
        redirect_to document_path(@document), notice: t(".created")
      else
        render :new, status: :unprocessable_content
      end
    end

    # The single PDF, once clean. A sensitive one only after the password, never during an
    # impersonate, and each opening is an access event (RN-08-081, P-08-20).
    def file
      authorize! :read, @document
      raise ActiveRecord::RecordNotFound unless @version.readable?
      if @document.sensitive?
        raise ActiveRecord::RecordNotFound if impersonating? || !sensitive_confirmed?

        AccessEvent.record!(kind: "sensitive_read", action: "document_opened", user: current_user, subject: @version,
          field: @document.category)
      end

      response.headers["Cache-Control"] = "private, no-store"
      response.headers["X-Frame-Options"] = "SAMEORIGIN"
      send_data @version.pdf.download, type: Documents::Upload::PDF, disposition: :inline,
        filename: "#{@document.document_type.name}-v#{@version.number}.pdf"
    end

    def approve
      authorize! :review, @document
      apply = chosen_fields
      if apply.keys.intersect?(WorkerProfile::DOCUMENT_FIELDS) && !(sensitive_confirmed? && !impersonating?)
        @version.errors.add(:base, :sensitive_unconfirmed)
        return reviewed(false, ".approved")
      end

      done = Documents::Review.new(@version, by: current_user)
        .approve(issued_on: parse_date(params[:issued_on]), valid_until: parse_date(params[:valid_until]), aso_result: params[:aso_result],
          apply: apply)
      reviewed(done, ".approved")
    end

    # "Processar de novo": the AI reads the version again, using credits (RN-14-121, RN-14-113).
    def reprocess
      authorize! :review, @document
      if Ai::Reprocess.call(@version, by: current_user)
        redirect_to document_path(@document, version_id: @version.id), notice: t(".queued")
      else
        @version.errors.add(:base, :not_reprocessable)
        reviewed(false, ".queued")
      end
    end

    def correction
      authorize! :review, @document
      done = Documents::Review.new(@version, by: current_user)
        .request_correction(reason: params[:correction_reason].presence_in(DocumentVersion::CORRECTION_REASONS), note: params[:correction_note])
      reviewed(done, ".requested")
    end

    private

    # Out of the person's reach answers 404 (RN-03-006).
    def load_document
      @document = Document.kept.accessible_by(current_ability, :read).includes(:document_type).find(params[:document_id])
    end

    def load_version
      @version = @document.versions.find(params[:id])
    end

    def reviewed(done, notice)
      if done
        redirect_to document_path(@document, version_id: @version.id), notice: t(notice)
      else
        redirect_to document_path(@document, version_id: @version.id), alert: @version.errors.full_messages.to_sentence
      end
    end

    # The fields the HR chose to put in the record, with the values as corrected (RN-08-021):
    # only the record's attributes a reading may fill; the review checks they belong to the type.
    def chosen_fields
      chosen = Array(params[:apply]).map(&:to_s)
      values = params.fetch(:values, {})
      Ai::ExtractionProfiles::APPLICABLE.select { |attribute| chosen.include?(attribute.to_s) }
        .to_h { |attribute| [ attribute, values[attribute].to_s.strip.presence ] }
    end

    def parse_date(value)
      Date.iso8601(value.to_s) if value.present?
    rescue Date::Error
      nil
    end
  end
end
