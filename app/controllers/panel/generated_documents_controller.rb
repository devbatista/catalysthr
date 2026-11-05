module Panel
  # The contracts and terms of an admission (RN-07-042, RN-07-043, D-650). The PDF stays in
  # the process, with the salary and the documents in it: it opens only for who runs the open
  # admission, after the password and as an access event, and only the signed one goes to the
  # folder. Closed, it opens only with the pay permission.
  class GeneratedDocumentsController < BaseController
    include SensitiveAccess

    before_action :require_current_company
    before_action :require_flag
    before_action :load_admission
    before_action :load_generated, only: %i[show signed]

    # Blank variables come back to be filled or confirmed (RN-07-042, CA-07-004).
    def create
      authorize! :update, @admission
      template = DocumentTemplate.active.for_kind(@admission.employment.kind).find(params[:document_template_id])
      generation = Documents::GenerateFromTemplate.new(@admission.employment, template)
      if (chars = generation.unsupported).any?
        return redirect_to admission_path(@admission), alert: t(".unsupported", chars: chars.join(" "))
      end
      if generation.missing.any? && params[:confirm_blank].blank?
        @template = template
        @missing = generation.missing
        return render :confirm
      end

      if generation.request(by: current_user)
        redirect_to admission_path(@admission, anchor: "contracts"), notice: t(".generating")
      else
        redirect_to admission_path(@admission, anchor: "contracts"), alert: t(".signed_already")
      end
    end

    def show
      authorize! :update, @admission
      authorize! :read_pay, @admission.worker_profile unless @admission.open?
      raise ActiveRecord::RecordNotFound if impersonating? || !@generated.file.attached?

      reveal_all_sections(%w[pay])
      return if performed?

      AccessEvent.record!(kind: "sensitive_read", action: "generated_document_opened", user: current_user, subject: @generated)
      response.headers["Cache-Control"] = "private, no-store"
      send_data @generated.file.download, type: Documents::Upload::PDF, disposition: :inline,
        filename: "#{@generated.document_template.name.parameterize}.pdf"
    end

    # The signed one, to the folder, as "Contrato assinado", through the usual review; it
    # answers the item that asks for it, when there is one (RN-07-043).
    def signed
      authorize! :update, @admission
      type = DocumentType.usable.find_by!(code: "signed_contract")
      upload = Documents::Upload.new(worker_profile: @admission.worker_profile, document_type: type, by: current_user,
        files: params[:files], process_item: open_item(type))
      if upload.save
        @generated.update!(signed_document: upload.document)
        redirect_to admission_path(@admission, anchor: "contracts"), notice: t(".signed")
      else
        redirect_to admission_path(@admission, anchor: "contracts"), alert: upload.errors.full_messages.to_sentence
      end
    end

    private

    def require_flag
      head :not_found unless FeatureFlags.enabled?(FeatureFlags::ADMISSIONS)
    end

    # Out of the person's reach answers 404 (RN-03-006).
    def load_admission
      @admission = Admission.accessible_by(current_ability, :read).find(params[:admission_id])
    end

    def load_generated
      @generated = GeneratedDocument.where(employment_id: @admission.employment_id).find(params[:id])
    end

    def open_item(type)
      @admission.process_instance.items.find do |item|
        item.document? && item.open? && item.config["document_type_id"] == type.id && !Document.kept.exists?(source_ref: item)
      end
    end
  end
end
