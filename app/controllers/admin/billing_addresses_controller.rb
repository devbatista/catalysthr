module Admin
  # The contract's billing address, the NFS-e's customer at Asaas (RN-19-103, D-635), kept
  # by the superadmin and the finance team. A change reaches Asaas before the next note.
  class BillingAddressesController < BillingController
    before_action :set_account

    def edit
      authorize! :update_billing_address, @account
    end

    def update
      authorize! :update_billing_address, @account
      @account.assign_attributes(params.expect(billing_account: BillingAccount::ADDRESS_FIELDS))

      if @account.save(context: :billing_address)
        redirect_to admin_client_path(@account), notice: t(".updated")
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_account
      @account = BillingAccount.find(params[:client_id])
    end
  end
end
