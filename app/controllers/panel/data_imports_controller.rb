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
