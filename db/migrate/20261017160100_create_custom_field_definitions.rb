# Extra fields the company creates for the person's record (RN-04-080, D-213). Removing a
# field inactivates it: the values stay in the records (RN-04-081, P-04-26).
class CreateCustomFieldDefinitions < ActiveRecord::Migration[8.1]
  def change
    create_table :custom_field_definitions do |t|
      t.references :company, null: false, foreign_key: true
      t.string :key, null: false
      t.string :label, null: false
      t.string :field_type, null: false
      t.jsonb :options, null: false, default: []
      t.boolean :required, null: false, default: false
      t.boolean :visible_to_employee, null: false, default: false
      t.boolean :editable_by_employee, null: false, default: false
      t.string :status, null: false, default: "active"
      t.timestamps
    end
    add_index :custom_field_definitions, %i[company_id key], unique: true
  end
end
