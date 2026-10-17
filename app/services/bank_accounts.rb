# Changes to the person's bank accounts (RN-04-044, D-604).
module BankAccounts
  module_function

  def end_primary!(profile)
    profile.bank_accounts.active.where(primary: true).find_each { |current| current.update!(status: "ended", ended_on: Date.current) }
  end

  # Makes an active account the primary, ending the current one (D-604).
  def make_primary!(account)
    BankAccount.transaction do
      account.worker_profile.lock!
      end_primary!(account.worker_profile)
      account.update!(primary: true)
    end
  end
end
