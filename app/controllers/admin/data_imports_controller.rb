module Admin
  # A company's imports done by the support or the superadmin on its behalf (RN-18-060 to
  # RN-18-062, D-666): the same flow and kinds as the company's panel (DataImportsFlow), only
  # with the HR administrator's authorization in force, checked at every step (CA-18-010). The
  # import is marked as assisted; the trail keeps who did it, and the company's history shows
  # "Importado pelo suporte CatalystHR". Undoing stays with the HR administrator (RN-18-050).
  class DataImportsController < BaseController
    before_action :load_company
    around_action :with_company
    include DataImportsFlow

    private

    def load_company
      @company = Company.find(params[:company_id])
    end

    def with_company(&)
      ActsAsTenant.with_tenant(@company, &)
    end

    def import_company = @company
    def import_area = :admin

    # Every kind (RN-18-060).
    def import_kinds = Imports::Kinds.all

    # Only with the company's authorization in force; without it, the list says why (CA-18-010).
    def import_allowed?(action, subject)
      authorize! :assist, :data_imports
      @authorization = AssistedImportAuthorization.current
      return true if @authorization || action == :read && subject == DataImport

      redirect_to admin_company_data_imports_path(@company), alert: t("admin.data_imports.unauthorized")
      false
    end

    def sensitive_ready?
      sensitive_confirmed?
    end

    def sensitive_confirmation_path_for(return_to)
      admin_new_sensitive_confirmation_path(return_to: return_to)
    end

    def import_path_for(action, import = nil, **params)
      case action
      when :index then admin_company_data_imports_path(@company, **params)
      when :new then new_admin_company_data_import_path(@company, **params)
      when :create then admin_company_data_imports_path(@company)
      when :template then template_admin_company_data_imports_path(@company, params.fetch(:kind))
      when :show then admin_company_data_import_path(@company, import)
      else send("#{action}_admin_company_data_import_path", @company, import, **params)
      end
    end
  end
end
