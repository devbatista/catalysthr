module Panel
  # The company's imports (spec 18, D-661, D-662): the flow is in DataImportsFlow. Here, also:
  # - the HR administrator undoes a whole import while nothing of it was used (D-665);
  # - the HR administrator authorizes the CatalystHR support to import on the company's
  #   behalf for 30 days, and revokes it (RN-18-061, D-666).
  class DataImportsController < BaseController
    before_action :require_current_company
    include DataImportsFlow

    # Undoes the whole import in the background, while nothing of it was used (RN-18-050 to
    # RN-18-052, D-665). It changes people's data back, so it asks for the password again.
    def undo
      @import = DataImport.find(params[:id])
      authorize! :undo, @import
      return redirect_to(data_import_path(@import), alert: t(".not_available")) unless Imports::Undo.available?(@import)
      return ask_sensitive_confirmation(data_import_path(@import)) unless sensitive_ready?
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

    # The authorization for the assisted import (RN-18-061, P-18-18, D-666): with the
    # password and the acceptance of the text, which also declares the bank accounts.
    def authorize_assisted
      authorize! :authorize, AssistedImportAuthorization
      return ask_sensitive_confirmation(data_imports_path) unless sensitive_ready?
      return redirect_to(data_imports_path, alert: t(".acceptance_missing")) unless params[:acceptance] == "1"
      return redirect_to(data_imports_path) if Simulation.active?

      authorization = AssistedImportAuthorization.grant!(by: current_user)
      AccessEvent.record!(kind: "admin", action: "assisted_import_authorized", user: current_user, subject: authorization)
      redirect_to data_imports_path, notice: t(".authorized", date: l(authorization.valid_until.to_date))
    end

    # "Liberar acesso de todos" (P-07-06, D-668): the invitation by e-mail to every admission of
    # the import still open and not released, in the background. Who has no e-mail stays in
    # the list, to be released on the admission's screen with the link or the QR code.
    def release_admissions
      @import = DataImport.find(params[:id])
      authorize! :release_admissions, @import
      return redirect_to(data_import_path(@import)) if Simulation.active? || !Imports::AdmissionsRelease.new(@import).releasable?

      AccessEvent.record!(kind: "admin", action: "import_admissions_released", user: current_user, subject: @import)
      Imports::ReleaseAdmissionsJob.perform_later(@import, current_user)
      redirect_to data_import_path(@import), notice: t(".queued")
    end

    # The mass update from the screen (RN-18-030, D-669): filter the people of the scope and
    # choose the change; the import has one line per employment found, with the same
    # preview and confirmation as the file. The salary only with the payroll module (P-03-16).
    def new_mass_update
      authorize! :create, DataImport
      return head(:not_found) unless Imports::MassUpdates.allowed?(current_ability)
      return ask_sensitive_confirmation(request.fullpath) unless sensitive_ready?

      mass_update_options
    end

    def create_mass_update
      authorize! :create, DataImport
      return head(:not_found) unless Imports::MassUpdates.allowed?(current_ability)
      return redirect_to(new_mass_update_data_imports_path) unless sensitive_ready?

      screen = mass_update_params
      if Imports::MassUpdates.screen_lines(DataImport.new(screen: screen), current_ability)[:mass_updates].empty?
        mass_update_options
        @error = :empty
        return render(:new_mass_update, status: :unprocessable_content)
      end
      return redirect_to(data_imports_path) if Simulation.active?

      import = DataImport.create!(kind: Imports::MassUpdates.code, created_by: current_user, screen: screen,
        original_filename: t(".screen_filename"))
      AccessEvent.record!(kind: "import", action: "upload", user: current_user, subject: import, metadata: { kind: import.kind, screen: true })
      Imports::ValidateJob.perform_later(import)
      redirect_to data_import_path(import)
    end

    def revoke_assisted
      authorize! :authorize, AssistedImportAuthorization
      authorization = AssistedImportAuthorization.current
      if authorization && !Simulation.active?
        authorization.revoke!(by: current_user)
        AccessEvent.record!(kind: "admin", action: "assisted_import_revoked", user: current_user, subject: authorization)
      end
      redirect_to data_imports_path, notice: t(".revoked")
    end

    private

    def import_company = Current.company
    def import_area = :panel

    def import_kinds
      Imports::Kinds.all.select { |kind| kind.allowed?(current_ability) }
    end

    def import_allowed?(_action, _subject) = true

    def mass_update_options
      @pay = current_ability.can?(:read_pay, WorkerProfile)
      @units = Unit.active.accessible_by(current_ability, :revise_in).ordered.to_a
      @departments = Department.active.where(unit: @units).includes(:unit).ordered.to_a
      @positions = Position.active.ordered.to_a
      @reasons = EmploymentRevision::CHANGE_REASONS
    end

    # Only the screen's fields; the salary only with the payroll module (P-03-16, D-669).
    def mass_update_params
      filters = params.fetch(:filters, {}).permit(*Imports::MassUpdates::SCREEN_FILTERS).to_h.compact_blank
      allowed = Imports::MassUpdates::SCREEN_CHANGES - (current_ability.can?(:read_pay, WorkerProfile) ? [] : %w[salary percent])
      changes = params.fetch(:changes, {}).permit(*allowed).to_h.compact_blank
      { "filters" => filters, "changes" => changes }
    end

    # The HR analyst sees only their own imports of admissions (D-668).
    def import_scope = DataImport.accessible_by(current_ability, :read)

    # During an impersonate nothing is recorded, and the password is not asked (RN-02-087).
    def sensitive_ready?
      impersonating? || sensitive_confirmed?
    end

    def sensitive_confirmation_path_for(return_to)
      new_sensitive_confirmation_path(return_to: return_to)
    end

    def import_path_for(action, import = nil, **params)
      case action
      when :index then data_imports_path(**params)
      when :new then new_data_import_path(**params)
      when :create then data_imports_path
      when :template then template_data_imports_path(params.fetch(:kind))
      when :show then data_import_path(import)
      else send("#{action}_data_import_path", import, **params)
      end
    end
  end
end
