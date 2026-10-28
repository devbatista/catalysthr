# The contract's customer in Asaas is unique (RN-19-103, D-633); built without blocking
# the table.
class AddAsaasCustomerIndexToBillingAccounts < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :billing_accounts, :asaas_customer_id, unique: true, algorithm: :concurrently
  end
end
