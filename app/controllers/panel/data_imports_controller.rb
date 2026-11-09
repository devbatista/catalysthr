module Panel
  # The company's imports (spec 18, section 4.1, D-661, D-662): choose the kind and download
  # its template, send the file, follow the validation, see the preview with the errors line
  # by line, confirm everything or only the valid lines, and see the result. Nothing is
  # recorded before the confirmation (D-462). Each sending and each confirmation is an access
  # event (RN-18-009).
  #
  # The HR administrator undoes a whole import while nothing of it was used (D-665).
  #
  # The kinds with people's data (D-663) ask for the password or a passkey again to send, to
  # confirm and to download the file of errors, which carry salaries, documents and accounts
  # (RN-18-041, RN-02-052); the pages show those values masked.
  class DataImportsController < BaseController
    include SensitiveAccess

    before_action :require_current_company
    before_action -> { head :not_found unless FeatureFlags.enabled?(FeatureFlags::DATA_IMPORTS) }
    before_action :load_import, only: %i[show confirm cancel undo errors]

    def index
      authorize! :read, DataImport
      @imports = DataImport.includes(:created_by).order(id: :desc).limit(100).to_a
      @kinds = Imports::Kinds.all.select { |kind| kind.allowed?(current_ability) }
    end

    def new
      authorize! :create, DataImport
      @kind = allowed_kind or return head(:not_found)
      require_sensitive_confirmation if @kind.sensitive?
    end

    def template
      authorize! :create, DataImport
      kind = allowed_kind or return head(:not_found)

      template = Imports::Template.new(kind)
      send_data template.to_xlsx, filename: template.filename,
        type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    end

    def create
      authorize! :create, DataImport
      @kind = allowed_kind or return head(:not_found)
      return redirect_to(new_data_import_path(kind: @kind.code)) if @kind.sensitive? && !sensitive_ready?

      file = params[:file]
      @error = upload_error(file)
      return render(:new, status: :unprocessable_content) if @error

      import = DataImport.new(kind: @kind.code, created_by: current_user, original_filename: file.original_filename.to_s.first(255))
      # An impersonate only simulates: nothing goes to the storage nor to the queue (RN-02-085).
      return redirect_to(data_imports_path) if Simulation.active?

      import.file.attach(blob(file))
      import.save!
      AccessEvent.record!(kind: "import", action: "upload", user: current_user, subject: import, metadata: { kind: import.kind })
      Imports::ValidateJob.perform_later(import)
      redirect_to data_import_path(import)
    end

    def show
      authorize! :read, @import
      @rows = @import.rows.where(status: %w[invalid failed]).limit(500).to_a
      @updates = @import.rows.status_valid.action_update.limit(200).to_a
      @sheets = @import.kind_class.sheets.index_by { |sheet| sheet.key.to_s }
    end

    # "Importar tudo" only without errors; otherwise "Importar só as válidas" (RN-18-001).
    def confirm
      authorize! :confirm, @import
      only_valid = params[:only_valid] == "1"
      return redirect_to(data_import_path(@import), alert: t(".not_ready")) unless @import.importable? && (only_valid || @import.all_valid?)
      if @import.kind_class.sensitive? && !sensitive_ready?
        return redirect_to(new_sensitive_confirmation_path(return_to: data_import_path(@import)))
      end
      # Who confirms the accounts declares they are in the people's CPF (P-04-17, D-663).
      if declaration?(@import.kind_class) && params[:declaration] != "1"
        return redirect_to(data_import_path(@import), alert: t(".declaration_missing"))
      end

      @import.with_lock do
        return redirect_to(data_import_path(@import)) unless @import.preview?

        @import.update!(status: "importing", confirmed_at: Time.current, options: @import.options.merge("only_valid" => only_valid))
      end
      AccessEvent.record!(kind: "import", action: "confirm", user: current_user, subject: @import, metadata: { kind: @import.kind })
      Imports::ApplyJob.perform_later(@import)
      redirect_to data_import_path(@import), notice: t(".confirmed")
    end

    # Undoes the whole import in the background, while nothing of it was used (RN-18-050 to
    # RN-18-052, D-665). It changes people's data back, so it asks for the password again.
    def undo
      authorize! :undo, @import
      return redirect_to(data_import_path(@import), alert: t(".not_available")) unless Imports::Undo.available?(@import)
      return redirect_to(new_sensitive_confirmation_path(return_to: data_import_path(@import))) unless sensitive_ready?
      # An impersonate only simulates: nothing goes to the queue (RN-02-085).
      return redirect_to(data_import_path(@import)) if Simulation.active?

      @import.with_lock do
        return redirect_to(data_import_path(@import)) unless @import.status.in?(Imports::Undo::UNDOABLE)

        @import.update!(status: "undoing", undo_blockers: nil, options: @import.options.merge("undo_from" => @import.status))
      end
      AccessEvent.record!(kind: "import", action: "undo", user: current_user, subject: @import, metadata: { kind: @import.kind })
      Imports::UndoJob.perform_later(@import, current_user)
      redirect_to data_import_path(@import)
    end

    def cancel
      authorize! :cancel, @import
      @import.update!(status: "cancelled") if @import.preview? || @import.failed?
      redirect_to data_imports_path, notice: t(".cancelled")
    end

    # The file back with the errors (RN-18-006): it carries what was sent, so it is an access
    # event.
    def errors
      authorize! :download_errors, @import
      if @import.kind_class.sensitive?
        require_sensitive_confirmation
        return if performed?
      end
      file = Imports::ErrorsFile.new(@import)
      return head(:not_found) unless file.available?

      AccessEvent.record!(kind: "download", action: "import_errors", user: current_user, subject: @import)
      send_data file.to_xlsx, filename: file.filename, type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    end

    private

    # During an impersonate nothing is recorded, and the password is not asked (RN-02-087).
    def sensitive_ready?
      impersonating? || sensitive_confirmed?
    end

    def declaration?(kind)
      kind.respond_to?(:declaration?) && kind.declaration?
    end
    helper_method :declaration?

    def load_import
      @import = DataImport.find(params[:id])
    end

    def allowed_kind
      code = params[:kind].presence_in(Imports::Kinds.codes)
      kind = code && Imports::Kinds.fetch(code)
      kind if kind&.allowed?(current_ability)
    end

    def upload_error(file)
      return :blank unless file.respond_to?(:original_filename)

      format = Imports::Reader.format_of(file.original_filename)
      return :format unless format && @kind.formats.include?(format)
      return :size if file.size > DataImport::MAX_SIZE

      nil
    end

    # Under the company's prefix in the storage, as the documents (P-08-07).
    def blob(file)
      ActiveStorage::Blob.create_and_upload!(io: file, filename: file.original_filename.to_s, content_type: file.content_type,
        identify: false, key: "companies/#{Current.company.id}/imports/#{SecureRandom.uuid}")
    end
  end
end
