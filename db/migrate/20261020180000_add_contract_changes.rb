# Changes to a contract (spec 19, RN-19-014, RN-19-015, RN-19-060, RN-19-061, D-620):
# private plans of a contract, the plan version scheduled for a later cycle (a reduction
# or a price migration) and the prorations charged on the next invoice.
class AddContractChanges < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :plans, :private, :boolean, null: false, default: false
    add_reference :plans, :billing_account, type: :uuid, index: { algorithm: :concurrently }
    add_foreign_key :plans, :billing_accounts, validate: false

    add_reference :subscriptions, :next_plan_version, type: :uuid, index: { algorithm: :concurrently }
    add_foreign_key :subscriptions, :plan_versions, column: :next_plan_version_id, validate: false
    add_column :subscriptions, :next_plan_version_on, :date
    add_column :subscriptions, :next_plan_version_reason, :string

    create_table :prorations, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :billing_account, type: :uuid, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :description, null: false
      t.date :effective_on, null: false
      t.bigint :total_cents, null: false
      # Null when the system causes it, as the partner's activation (D-612).
      t.references :created_by, type: :uuid, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_reference :invoice_lines, :proration, type: :uuid, index: { unique: true, algorithm: :concurrently }
    add_foreign_key :invoice_lines, :prorations, validate: false
  end
end
