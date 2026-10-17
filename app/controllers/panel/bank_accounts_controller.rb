module Panel
  # Where the person is paid (RN-04-044): a new account or PIX key, the primary one, and
  # ending an account, which stays as history (D-604, CA-04-008). Bank data is pay: only
  # with the payroll module for the HR analyst (P-03-16).
  class BankAccountsController < EmployeeRecordsController
    before_action :load_account, only: %i[make_primary close]

    def new
      authorize! :update, @profile
      authorize! :read_pay, @profile
      @account = @profile.bank_accounts.new(primary: @profile.bank_accounts.active.none?)
    end

    def create
      authorize! :update, @profile
      authorize! :read_pay, @profile
      primary = params.dig(:bank_account, :primary) == "1"
      # The HR declares that the account is the person's (P-04-17).
      unless params[:declaration] == "1"
        @account = @profile.bank_accounts.new(account_params.merge(primary: primary))
        @account.errors.add(:base, :declaration_missing)
        return render(:new, status: :unprocessable_content)
      end

      @account = BankAccounts::Register.call(profile: @profile, attributes: account_params, primary: primary, by: current_user)
      return back_to_profile(notice: t(".created")) if @account.persisted?

      render :new, status: :unprocessable_content
    end

    def make_primary
      authorize! :update, @profile
      authorize! :read_pay, @profile
      BankAccounts.make_primary!(@account)
      back_to_profile(notice: t(".made_primary"))
    end

    def close
      authorize! :update, @profile
      authorize! :read_pay, @profile
      @account.update!(status: "ended", ended_on: Date.current)
      back_to_profile(notice: t(".closed"))
    end

    private

    def load_account
      @account = @profile.bank_accounts.active.find(params[:id])
    end

    # Either the bank account or the PIX key, by the form's choice.
    def account_params
      permitted = params.expect(bank_account: %i[bank_code branch account_number account_type pix_key_type pix_key])
      if params.dig(:bank_account, :method) == "pix"
        permitted.slice(:pix_key_type, :pix_key)
      else
        permitted.slice(:bank_code, :branch, :account_number, :account_type)
      end
    end
  end
end
