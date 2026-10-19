# The modules the partner turns on or off for each company of the portfolio (RN-19-012,
# D-616).
class CreateCompanyModuleSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :company_module_settings, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: false
      t.string :module, null: false
      t.boolean :enabled, null: false, default: true
      t.references :changed_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.datetime :changed_at, null: false
      t.timestamps
    end
    add_index :company_module_settings, %i[company_id module], unique: true
  end
end
