# The contract's billing address kept by the client's financial responsible: the
# partner's administrator or the direct company's HR administrator (RN-19-044, D-635).
# It is the NFS-e's customer at Asaas, and a change reaches Asaas before the next note.
# Open while the contract is read only, as paying is (D-624).
module ClientBillingAddress
  extend ActiveSupport::Concern

  included do
    writes_while_locked :update
    before_action :require_billing_feature
  end

  def edit
    authorize! :update_billing_address, billing_account_owner
    @account = billing_account.suggest_headquarters_address
    render "shared/billing_address/edit"
  end

  def update
    authorize! :update_billing_address, billing_account_owner
    @account = billing_account
    @account.assign_attributes(params.expect(billing_account: BillingAccount::ADDRESS_FIELDS))

    if @account.save(context: :billing_address)
      redirect_to billing_address_invoices_path, notice: t("shared.billing_address.updated")
    else
      render "shared/billing_address/edit", status: :unprocessable_content
    end
  end

  private

  def billing_account
    billing_account_owner.billing_account || raise(ActiveRecord::RecordNotFound)
  end
end
