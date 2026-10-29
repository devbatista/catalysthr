# The contract's billing address, sent to Asaas as the NFS-e's customer (RN-19-103, D-635).
class AddBillingAddressToBillingAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :billing_accounts, :postal_code, :string
    add_column :billing_accounts, :street, :string
    add_column :billing_accounts, :street_number, :string
    add_column :billing_accounts, :complement, :string
    add_column :billing_accounts, :district, :string
    add_column :billing_accounts, :city, :string
    add_column :billing_accounts, :state, :string
  end
end
