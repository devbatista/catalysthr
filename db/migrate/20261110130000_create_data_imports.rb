# Block 18a of spec 18 (D-661, D-662): the common import engine (section 7). The file stays
# 90 days (RN-18-010). Each row keeps what was read, its errors and the fields it changes,
# encrypted, because they carry CPF, salary and bank data, and the messages repeat the value
# (D-086, D-661). After the 90 days only the counts and the messages stay.
class CreateDataImports < ActiveRecord::Migration[8.1]
  def change
    create_table :data_imports, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: false
      t.string :kind, null: false
      t.string :status, null: false, default: "uploaded"
      t.string :original_filename, null: false
      t.integer :row_count, null: false, default: 0
      t.integer :valid_count, null: false, default: 0
      t.integer :created_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.integer :unchanged_count, null: false, default: 0
      t.integer :error_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.string :failure_reason
      t.jsonb :options, null: false, default: {}
      t.references :created_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.boolean :assisted, null: false, default: false
      t.datetime :validated_at
      t.datetime :confirmed_at
      t.datetime :finished_at
      t.datetime :purged_at
      t.datetime :undone_at
      t.references :undone_by, type: :uuid, foreign_key: { to_table: :users }
      t.timestamps
      t.index %i[company_id created_at]
      t.index %i[status created_at]
    end

    create_table :data_import_rows, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: false
      t.references :data_import, type: :uuid, null: false, foreign_key: true, index: false
      t.string :sheet, null: false
      t.integer :line_number, null: false
      t.integer :position, null: false
      t.string :status, null: false
      t.string :action, null: false, default: "none"
      t.text :payload
      t.text :issues
      t.text :diff
      t.string :record_type
      t.uuid :record_id
      t.timestamps
      t.index %i[data_import_id position], unique: true
      t.index %i[data_import_id status]
    end
  end
end
