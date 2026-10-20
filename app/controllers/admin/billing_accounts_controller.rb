module Admin
  # Partners and direct companies with their contracts (RN-19-080, RN-19-081). The
  # superadmin and the finance team register them, with a trial or a contract starting
  # today (D-613); the support reads (spec 19, section 6).
  class BillingAccountsController < BillingController
    def index
      authorize! :read, BillingAccount
      @accounts = BillingAccount.includes(:owner, subscription: { plan_version: :plan }).ordered.reverse_order
    end

    def new
      authorize! :create, BillingAccount
      @registration = Billing::ClientRegistration.new(kind: known_kind(params[:kind]))
    end

    def create
      authorize! :create, BillingAccount
      @registration = Billing::ClientRegistration.new(registration_params)

      if @registration.save(by: current_user)
        notice = @registration.existing_person? ? t(".created_existing_person") : t(".created", email: @registration.admin_email)
        redirect_to admin_client_path(@registration.billing_account), notice: notice
      else
        render :new, status: :unprocessable_content
      end
    end

    def show
      @account = BillingAccount.includes(:responsible_user, subscription: [ { plan_version: :plan }, :pre_activation_price,
        { items: { add_on_price: :add_on } } ]).find(params[:id])
      authorize! :read, @account
      @invoices = @account.invoices.recent_first
      @adjustments = @account.billing_adjustments.includes(:created_by, :invoice_lines).newest_first
      return unless can?(:change_contract, @account)

      @offered_plans = Plan.offered_to(@account).includes(plan_versions: :plan_modules).ordered.select(&:version_on)
      @add_ons = AddOn.active.includes(:prices).order(:code)
    end

    private

    def known_kind(kind)
      kind.in?(Billing::ClientRegistration::KINDS) ? kind : raise(ActiveRecord::RecordNotFound)
    end

    def registration_params
      attributes = params.expect(client: [ :kind, :mode, :legal_name, :commercial_name, :cnpj, :slug, :plan_id,
        :admin_name, :admin_cpf, :admin_email, { modules: [], add_on_codes: [] } ])
      attributes.merge(kind: known_kind(attributes[:kind]))
    end
  end
end
