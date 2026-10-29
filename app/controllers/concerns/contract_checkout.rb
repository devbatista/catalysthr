# The contracting by the client during the trial or in the 30 days after it (RN-19-033,
# RN-19-034, D-622), for the partner's administrator and the direct company's HR
# administrator, the financial responsible (RN-19-044). The first invoice opens with its PIX.
# A contract without the billing address asks for it here, before the first payment,
# filled with the headquarters' address when there is one (D-635).
module ContractCheckout
  extend ActiveSupport::Concern

  included do
    helper_method :checkout_form_path, :checkout_invoice_path, :billing_address_lookup_url
  end

  private

  def checkout_form(account)
    @account = account
    @subscription = account&.subscription
    @plans = Plan.offered_to(account).includes(plan_versions: :plan_modules).ordered.select(&:version_on) if account
    @plan_id ||= @subscription&.plan_version&.plan_id
    @modules ||= @subscription&.modules || []
    @pending = Billing::Checkout.pending_invoice(account) if account
    @address_needed = account && !account.billing_address_complete? if @address_needed.nil?
    account&.suggest_headquarters_address if @address_needed
    # The partner with no active employee starts on the pre-activation fee (RN-19-035).
    @pre_activation_price = PreActivationPrice.on if account&.partner? && Billing::Usage.active_employees(account, Date.current).zero?
  end

  # Renders the form, or goes to the invoices when there is nothing to contract.
  def render_checkout(account, status: :ok)
    checkout_form(account)
    return redirect_to(checkout_invoices_path, notice: t("shared.contracts.form.not_open")) unless Billing::Checkout.open?(@subscription)

    render "shared/contracts/new", status: status
  end

  def start_checkout(account)
    @plan_id = params[:plan_id]
    @modules = Array(params[:modules]).compact_blank
    return render_checkout(account) unless Billing::Checkout.open?(account&.subscription)
    return render_checkout(account, status: :unprocessable_content) unless save_billing_address(account)

    invoice = Billing::Checkout.start(account, plan: Plan.offered_to(account).find_by(id: @plan_id), modules: @modules)
    redirect_to checkout_invoice_path(invoice), notice: t("shared.contracts.form.started")
  rescue Billing::Checkout::Error
    flash.now[:alert] = t("shared.contracts.form.invalid")
    render_checkout(account, status: :unprocessable_content)
  end

  def save_billing_address(account)
    @address_needed = !account.billing_address_complete?
    return true unless @address_needed

    account.assign_attributes(params.fetch(:billing_account, {}).permit(*BillingAccount::ADDRESS_FIELDS))
    account.save(context: :billing_address)
  end
end
