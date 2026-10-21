# The contracting by the client during the trial or after it (spec 19, RN-19-033, RN-19-034,
# D-622): its invoice, due that day, is marked as the checkout's, and an unpaid one is voided
# the next day with the reason. A cycle may then have one voided invoice and the paid one, so
# the unique index of the cycle leaves the voided out.
class AddCheckoutToInvoices < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :invoices, :checkout, :boolean, null: false, default: false
    add_column :invoices, :void_reason, :string
    add_column :invoices, :voided_at, :datetime

    add_index :invoices, %i[billing_account_id period_start], unique: true, where: "status <> 'void'",
      name: "index_invoices_on_account_period_start_not_void", algorithm: :concurrently
    remove_index :invoices, %i[billing_account_id period_start], unique: true,
      name: "index_invoices_on_billing_account_id_and_period_start", algorithm: :concurrently
  end
end
