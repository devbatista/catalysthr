# Contracts and subscriptions (spec 19, RN-19-001, RN-19-002, D-613): who pays, a partner
# or a direct company, and its plan version, modules and add-ons. The partner pays a
# symbolic fee until the first active employee in the portfolio (RN-19-035, D-612), a
# single value with versions like the prices (D-611). The payment, the cycle's dates and
# the cancellation come with blocks 19d to 19h.
class CreateBillingAccountsAndSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :pre_activation_prices do |t|
      t.integer :version, null: false
      t.date :valid_from, null: false
      t.integer :monthly_price_cents, null: false
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :pre_activation_prices, :version, unique: true

    create_table :billing_accounts do |t|
      t.references :owner, polymorphic: true, null: false, index: { unique: true }
      t.references :responsible_user, foreign_key: { to_table: :users }
      t.string :billing_email
      t.integer :cycle_day, null: false
      t.timestamps
    end

    create_table :subscriptions do |t|
      t.references :billing_account, null: false, foreign_key: true, index: { unique: true }
      t.references :plan_version, null: false, foreign_key: true
      t.references :pre_activation_price, foreign_key: true
      t.string :status, null: false
      t.date :started_on, null: false
      t.date :trial_ends_on
      t.date :activated_on
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    create_table :subscription_items do |t|
      t.references :subscription, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :module
      t.references :add_on_price, foreign_key: true
      t.date :starts_on, null: false
      t.date :ends_on
      t.timestamps
    end
  end
end
