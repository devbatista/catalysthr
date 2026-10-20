# The manual adjustments of a contract's next invoices (spec 19, section 7, RN-19-070,
# RN-19-071, D-621): discount, credit or overage waiver, with the reason, who launched and
# who approved. The invoice lines that apply each one say how much was used.
class CreateBillingAdjustments < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    create_table :billing_adjustments, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :billing_account, type: :uuid, null: false, foreign_key: true
      t.string :kind, null: false
      t.bigint :value_cents
      t.decimal :percent, precision: 5, scale: 2
      t.integer :cycles, null: false, default: 1
      t.string :overage_scope
      t.text :reason, null: false
      t.string :status, null: false
      t.references :created_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.references :approved_by, type: :uuid, foreign_key: { to_table: :users }
      t.datetime :approved_at
      t.references :cancelled_by, type: :uuid, foreign_key: { to_table: :users }
      t.datetime :cancelled_at
      t.timestamps
    end
    add_index :billing_adjustments, :status

    add_reference :invoice_lines, :billing_adjustment, type: :uuid, index: { algorithm: :concurrently }
    add_foreign_key :invoice_lines, :billing_adjustments, validate: false
  end
end
