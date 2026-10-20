module Admin
  # The superadmin and the finance team change a contract's plan, modules and add-ons, and
  # migrate it to the plan's newer price (RN-19-014, RN-19-060, RN-19-061, D-620). An
  # increase takes effect at once, with the proportional difference on the next invoice; a
  # reduction after the last day invoiced. A contract in closing or closed does not change.
  class ContractChangesController < BillingController
    before_action :load_contract

    def change_plan
      authorize! :change_contract, @account
      return back_closed if closed?

      plan = Plan.offered_to(@account).find_by(id: params[:plan_id])
      # The contract's own plan at a newer price is a price migration, with 30 days' notice
      # (RN-19-014), never a change of plan.
      return back(alert: t(".same_plan")) if plan == @subscription.plan

      version = plan&.version_on
      return back(alert: t(".unavailable")) if version.nil?

      result = Billing::ContractChanges.change_plan(@subscription, version, by: current_user)
      return back(notice: t(".scheduled", plan: version.plan.name, date: l(result.effective_on))) if result.effective_on > Date.current

      back(notice: changed(t(".changed", plan: version.plan.name), result))
    end

    def cancel_scheduled
      authorize! :change_contract, @account
      return back_closed if closed?

      Billing::ContractChanges.cancel_scheduled(@subscription)
      back(notice: t(".cancelled"))
    end

    def migrate_price
      authorize! :change_contract, @account
      return back_closed if closed?

      result = Billing::ContractChanges.migrate_price(@subscription)
      back(**(result ? { notice: t(".scheduled", date: l(result.effective_on)) } : { alert: t(".nothing") }))
    end

    def add_module
      authorize! :change_contract, @account
      return back_closed if closed?

      code = known_module
      result = Billing::ContractChanges.add_module(@subscription, code, by: current_user)
      back(notice: changed(t(".added", module: t("modules.#{code}")), result))
    end

    def remove_module
      authorize! :change_contract, @account
      return back_closed if closed?

      code = known_module
      result = Billing::ContractChanges.remove_module(@subscription, code)
      return back(alert: t(".absent")) if result.nil?

      back(notice: t(".removed", module: t("modules.#{code}"), date: l(result.effective_on)))
    end

    def add_add_on
      authorize! :change_contract, @account
      return back_closed if closed?

      add_on = AddOn.active.find_by!(code: params[:code])
      return back(alert: t(".without_price")) if add_on.price_on.nil?

      result = Billing::ContractChanges.add_add_on(@subscription, add_on, by: current_user)
      back(notice: changed(t(".added", add_on: t("add_ons.names.#{add_on.code}")), result))
    end

    def remove_add_on
      authorize! :change_contract, @account
      return back_closed if closed?

      add_on = AddOn.find_by!(code: params[:code])
      result = Billing::ContractChanges.remove_add_on(@subscription, add_on)
      return back(alert: t(".absent")) if result.nil?

      back(notice: t(".removed", add_on: t("add_ons.names.#{add_on.code}"), date: l(result.effective_on)))
    end

    private

    def load_contract
      @account = BillingAccount.find(params[:client_id])
      @subscription = @account.subscription
    end

    def closed?
      @subscription.nil? || @subscription.closing? || @subscription.closed?
    end

    def back_closed
      back(alert: t("admin.contract_changes.closed"))
    end

    def known_module
      params[:code].presence_in(PlanModule::MODULES) || raise(ActiveRecord::RecordNotFound)
    end

    # The change done, with the proration that goes into the next invoice, if any.
    def changed(message, result)
      return message if result.proration.nil?

      "#{message} #{t("admin.contract_changes.proration", amount: "R$ #{MoneyCents.format(result.proration.total_cents)}")}"
    end

    def back(**flash)
      redirect_to admin_client_path(@account), **flash
    end
  end
end
