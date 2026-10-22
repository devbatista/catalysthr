# The cancellation asked by the client and its undo (RN-19-062, RN-19-063, D-625), for the
# partner's administrator and the direct company's HR administrator, the financial
# responsible (RN-19-044). Both ask for the password again (RN-19-062, RN-02-052).
module ContractCancellation
  extend ActiveSupport::Concern
  include SensitiveAccess

  included do
    helper_method :cancellation_form_path
  end

  private

  def show_cancellation(account, status: :ok)
    @account = account
    @subscription = account&.subscription
    if Billing::Cancellation.scheduled?(@subscription)
      render "shared/cancellations/show", status: status
    elsif @subscription&.status.in?(Billing::Cancellation::CANCELLABLE)
      return require_sensitive_confirmation unless confirmed?

      @cancel_on, @to_void = Billing::Cancellation.effective_on(account, Date.current)
      render "shared/cancellations/show", status: status
    else
      redirect_to cancellation_invoices_path, alert: t("shared.cancellations.show.not_cancellable")
    end
  end

  def create_cancellation(account)
    return require_sensitive_confirmation unless confirmed?

    result = Billing::Cancellation.schedule(account.subscription, by: current_user, reason: params[:reason], text: params[:reason_text])
    return redirect_to(cancellation_form_path, notice: t("shared.cancellations.show.scheduled")) if result == :scheduled

    flash.now[:alert] = t("shared.cancellations.show.errors.#{result}")
    show_cancellation(account, status: :unprocessable_content)
  end

  def destroy_cancellation(account)
    return require_sensitive_confirmation unless confirmed?

    result = Billing::Cancellation.undo(account.subscription, by: current_user)
    if result == :undone
      redirect_to cancellation_invoices_path, notice: t("shared.cancellations.show.undone")
    else
      redirect_to cancellation_form_path, alert: t("shared.cancellations.show.errors.#{result}")
    end
  end

  # The password again, except during an impersonate, whose writes are simulated (RN-02-087).
  def confirmed?
    impersonating? || sensitive_confirmed?
  end
end
