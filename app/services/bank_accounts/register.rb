module BankAccounts
  # Adds an account or a PIX key to the person's record (RN-04-044). As the primary, it
  # ends the previous primary, which stays in the record as history (D-604, CA-04-008).
  # The HR declares that the owner's CPF is the person's (P-04-17).
  class Register
    def self.call(**)
      new(**).call
    end

    def initialize(profile:, attributes:, primary:, by:)
      @profile = profile
      @attributes = attributes
      @primary = primary
      @by = by
    end

    def call
      account = @profile.bank_accounts.new(@attributes.merge(primary: @primary, declared_by: @by, declared_at: Time.current))
      BankAccount.transaction do
        @profile.lock!
        BankAccounts.end_primary!(@profile) if @primary && account.valid?
        account.save!
      end
      account
    rescue ActiveRecord::RecordInvalid
      account
    end
  end
end
