# Plans, modules and add-ons of the CatalystHR (spec 19, RN-19-010 to RN-19-014, D-611).
# The plan keeps its kind, name and status; prices, limits, quotas and the modules' prices
# live in versions that never change. Add-on prices have versions too. Amounts in cents.
# Private plans (RN-19-015) come with the contracts, in block 19b.
class CreatePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :plans do |t|
      t.string :kind, null: false
      t.string :name, null: false
      t.string :status, null: false, default: "active"
      t.timestamps
    end
    add_index :plans, "kind, lower(name)", unique: true, name: "index_plans_on_kind_and_name"

    create_table :plan_versions do |t|
      t.references :plan, null: false, foreign_key: true, index: false
      t.integer :version, null: false
      t.date :valid_from, null: false
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      # Partner plan (D-480): fixed price for a band of employees, with overage above it.
      t.integer :monthly_price_cents
      t.integer :employee_limit
      t.integer :overage_per_employee_cents
      t.integer :ai_credits
      t.integer :whatsapp_messages
      # Direct company plan (D-122): price per active employee, with a monthly minimum.
      t.integer :price_per_employee_cents
      t.integer :minimum_monthly_cents
      t.integer :ai_credits_per_employee
      t.integer :whatsapp_messages_per_employee
      # Both kinds.
      t.integer :ai_credit_overage_cents, null: false
      t.integer :whatsapp_overage_cents, null: false
      t.timestamps
    end
    add_index :plan_versions, %i[plan_id version], unique: true

    create_table :plan_modules do |t|
      t.references :plan_version, null: false, foreign_key: true, index: false
      t.string :module, null: false
      t.integer :price_cents, null: false
      t.timestamps
    end
    add_index :plan_modules, %i[plan_version_id module], unique: true

    create_table :add_ons do |t|
      t.string :code, null: false
      t.string :status, null: false, default: "active"
      t.timestamps
    end
    add_index :add_ons, :code, unique: true

    create_table :add_on_prices do |t|
      t.references :add_on, null: false, foreign_key: true, index: false
      t.integer :version, null: false
      t.date :valid_from, null: false
      t.integer :monthly_price_cents, null: false
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :add_on_prices, %i[add_on_id version], unique: true
  end
end
