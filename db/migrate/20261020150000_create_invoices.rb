# The invoices of each contract's cycle, with their lines (spec 19, section 7, RN-19-040,
# RN-19-041, D-619). The payment columns come with the Mercado Pago blocks (19e, 19h).
class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :billing_account, type: :uuid, null: false, foreign_key: true, index: false
      t.bigint :number, null: false
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.date :due_on, null: false
      t.string :status, null: false, default: "open"
      t.bigint :total_cents, null: false
      # The closed month whose usage the invoice charges (D-619), when there is one.
      t.string :usage_period
      t.datetime :issued_at, null: false
      t.timestamps
    end
    add_index :invoices, %i[billing_account_id period_start], unique: true
    add_index :invoices, :number, unique: true
    add_index :invoices, %i[status due_on]

    create_table :invoice_lines, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :invoice, type: :uuid, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :kind, null: false
      t.string :description, null: false
      t.integer :quantity, null: false
      t.bigint :unit_cents, null: false
      t.bigint :total_cents, null: false
      t.timestamps
    end
  end
end
