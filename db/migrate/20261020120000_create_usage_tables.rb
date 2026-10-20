# The usage of each contract (spec 19, section 7): the employees active on each day, with
# the modules the company used that day, and the month of each company and of the whole
# contract (RN-19-020 to RN-19-024, D-618).
class CreateUsageTables < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_usages, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :billing_account, type: :uuid, null: false, foreign_key: true, index: false
      t.references :company, type: :uuid, null: false, foreign_key: true, index: false
      t.date :date, null: false
      t.integer :active_employees, null: false, default: 0
      t.string :modules, array: true, null: false, default: []
      t.timestamps
    end
    add_index :daily_usages, %i[company_id date], unique: true
    add_index :daily_usages, %i[billing_account_id date]

    create_table :usage_periods, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :billing_account, type: :uuid, null: false, foreign_key: true, index: false
      # Null on the contract's total.
      t.references :company, type: :uuid, foreign_key: true, index: false
      t.string :period, null: false
      t.integer :peak_employees, null: false, default: 0
      t.integer :ai_credits, null: false, default: 0
      t.integer :whatsapp_messages, null: false, default: 0
      t.string :modules, array: true, null: false, default: []
      # The highest threshold of the employee band already notified (80 or 100), on the total.
      t.integer :employees_alerted_percent
      t.datetime :closed_at
      t.timestamps
    end
    add_index :usage_periods, %i[billing_account_id period company_id], unique: true, nulls_not_distinct: true,
      name: "index_usage_periods_on_account_period_company"
    add_index :usage_periods, %i[company_id period]
  end
end
