# The platform's fiscal settings for the NFS-e (spec 19, RN-19-102, D-632, D-633): what
# goes on every note sent to Asaas. The Asaas account's own setup (certificate or portal
# login, DPS series, regime) stays in Asaas's panel. A single row, kept by the unique
# `singleton` column.
class CreateFiscalSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :fiscal_settings, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.boolean :singleton, null: false, default: true
      t.string :service_code, null: false
      t.string :service_name, null: false
      t.string :nbs_code, null: false
      t.string :operation_indicator_code, null: false
      t.text :description, null: false
      t.text :observations, null: false
      t.boolean :retain_iss, null: false, default: false
      t.decimal :pis_rate, precision: 5, scale: 2, null: false, default: 0
      t.decimal :cofins_rate, precision: 5, scale: 2, null: false, default: 0
      t.decimal :csll_rate, precision: 5, scale: 2, null: false, default: 0
      t.decimal :inss_rate, precision: 5, scale: 2, null: false, default: 0
      t.decimal :ir_rate, precision: 5, scale: 2, null: false, default: 0
      t.references :updated_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :fiscal_settings, :singleton, unique: true
  end
end
