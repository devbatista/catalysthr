# The flow of an import (spec 18, section 4.1, D-661, D-662), the same in the company's panel
# and, for the assisted import, in the admin area (RN-18-060, D-666): choose the kind and
# download its template, send the file, follow the validation, see the preview with the
# errors line by line, confirm everything or only the valid lines, and see the result.
# Nothing is recorded before the confirmation (D-462). Each sending, confirmation and download
# of the errors is an access event (RN-18-009).
#
# The kinds with people's data (D-663) ask for the password again to send, to confirm and to
# download the file of errors, which carry salaries, documents and accounts (RN-18-041,
# RN-02-052); the pages show those values masked.
#
# The controller gives: import_company, import_kinds, import_path_for(action, import, **params),
# import_area (:panel or :admin), import_allowed?(action, subject), checked after authorize!,
# which may redirect and return false, and sensitive_ready?.
module DataImportsFlow
  extend ActiveSupport::Concern

  XLSX = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet".freeze
  VIEWS = "panel/data_imports".freeze

  included do
    include SensitiveAccess

    before_action -> { head :not_found unless FeatureFlags.enabled?(FeatureFlags::DATA_IMPORTS) }
    before_action :load_import, only: %i[show confirm cancel errors]
    helper_method :import_path_for, :import_area, :declaration?
  end

  def index
    authorize! :read, DataImport
    return unless import_allowed?(:read, DataImport)
    @imports = import_scope.includes(:created_by).order(id: :desc).limit(100).to_a
    @kinds = import_kinds
    render "#{VIEWS}/index"
  end

  def new
    authorize! :create, DataImport
    return unless import_allowed?(:create, DataImport)
    @kind = allowed_kind or return head(:not_found)
    return ask_sensitive_confirmation(request.fullpath) if @kind.sensitive? && !sensitive_ready?

    render "#{VIEWS}/new"
  end

  def template
    authorize! :create, DataImport
    return unless import_allowed?(:create, DataImport)
    kind = allowed_kind or return head(:not_found)

    template = Imports::Template.new(kind)
    send_data template.to_xlsx, filename: template.filename, type: XLSX
  end

  def create
    authorize! :create, DataImport
    return unless import_allowed?(:create, DataImport)
    @kind = allowed_kind or return head(:not_found)
    return redirect_to(import_path_for(:new, kind: @kind.code)) if @kind.sensitive? && !sensitive_ready?

    file = params[:file]
    @error = upload_error(file)
    return render("#{VIEWS}/new", status: :unprocessable_content) if @error

    import = DataImport.new(kind: @kind.code, created_by: current_user, assisted: import_area == :admin,
      original_filename: file.original_filename.to_s.first(255))
    # An impersonate only simulates: nothing goes to the storage nor to the queue (RN-02-085).
    return redirect_to(import_path_for(:index)) if Simulation.active?

    import.file.attach(blob(file))
    import.save!
    AccessEvent.record!(kind: "import", action: "upload", user: current_user, subject: import, metadata: { kind: import.kind })
    Imports::ValidateJob.perform_later(import)
    redirect_to import_path_for(:show, import)
  end

  def show
    authorize! :read, @import
    return unless import_allowed?(:read, @import)
    @rows = @import.rows.where(status: %w[invalid failed]).limit(500).to_a
    @updates = @import.rows.status_valid.action_update.limit(200).to_a
    @sheets = @import.kind_class.sheets.index_by { |sheet| sheet.key.to_s }
    render "#{VIEWS}/show"
  end

  # "Importar tudo" only without errors; otherwise "Importar só as válidas" (RN-18-001).
  def confirm
    authorize! :confirm, @import
    return unless import_allowed?(:confirm, @import)
    only_valid = params[:only_valid] == "1"
    unless @import.importable? && (only_valid || @import.all_valid?)
      return redirect_to(import_path_for(:show, @import), alert: t("panel.data_imports.confirm.not_ready"))
    end
    return ask_sensitive_confirmation(import_path_for(:show, @import)) if @import.kind_class.sensitive? && !sensitive_ready?
    # Who confirms the accounts declares they are in the people's CPF (P-04-17, D-663, D-666).
    if declaration?(@import.kind_class) && params[:declaration] != "1"
      return redirect_to(import_path_for(:show, @import), alert: t("panel.data_imports.confirm.declaration_missing"))
    end

    @import.with_lock do
      return redirect_to(import_path_for(:show, @import)) unless @import.preview?

      @import.update!(status: "importing", confirmed_at: Time.current, options: @import.options.merge("only_valid" => only_valid))
    end
    AccessEvent.record!(kind: "import", action: "confirm", user: current_user, subject: @import, metadata: { kind: @import.kind })
    Imports::ApplyJob.perform_later(@import)
    redirect_to import_path_for(:show, @import), notice: t("panel.data_imports.confirm.confirmed")
  end

  def cancel
    authorize! :cancel, @import
    return unless import_allowed?(:cancel, @import)
    @import.update!(status: "cancelled") if @import.preview? || @import.failed?
    redirect_to import_path_for(:index), notice: t("panel.data_imports.cancel.cancelled")
  end

  # The file back with the errors (RN-18-006): it carries what was sent, so it is an access
  # event.
  def errors
    authorize! :download_errors, @import
    return unless import_allowed?(:download_errors, @import)
    return ask_sensitive_confirmation(request.fullpath) if @import.kind_class.sensitive? && !sensitive_ready?

    file = Imports::ErrorsFile.new(@import)
    return head(:not_found) unless file.available?

    AccessEvent.record!(kind: "download", action: "import_errors", user: current_user, subject: @import)
    send_data file.to_xlsx, filename: file.filename, type: XLSX
  end

  private

  # The imports the list shows; the panel narrows them to the person's (D-668).
  def import_scope = DataImport.all

  def declaration?(kind)
    kind.respond_to?(:declaration?) && kind.declaration?
  end

  def ask_sensitive_confirmation(return_to)
    redirect_to sensitive_confirmation_path_for(return_to)
  end

  def load_import
    @import = DataImport.find(params[:id])
  end

  def allowed_kind
    code = params[:kind].presence_in(Imports::Kinds.codes)
    kind = code && Imports::Kinds.fetch(code)
    kind if kind && import_kinds.include?(kind)
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
      identify: false, key: "companies/#{import_company.id}/imports/#{SecureRandom.uuid}")
  end
end
