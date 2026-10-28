# The NFS-e of each paid invoice, issued through Asaas (spec 19, section 7, RN-19-100 to
# RN-19-111, D-633): one per invoice, with its status, what was sent and what Asaas
# answered. The contract keeps its customer id in Asaas (RN-19-103).
class CreateServiceInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :service_invoices, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :invoice, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.string :status, null: false
      t.bigint :amount_cents, null: false
      t.date :competence_on, null: false
      t.date :effective_on
      t.text :service_description
      t.string :service_code
      t.string :asaas_invoice_id
      t.string :number
      t.string :verification_code
      t.datetime :authorized_at
      t.text :error_message
      t.integer :errors_count, null: false, default: 0
      t.string :cancel_reason
      t.datetime :cancelled_at
      t.timestamps
    end
    add_index :service_invoices, :asaas_invoice_id, unique: true
    add_index :service_invoices, :status

    add_column :billing_accounts, :asaas_customer_id, :string
  end
end
