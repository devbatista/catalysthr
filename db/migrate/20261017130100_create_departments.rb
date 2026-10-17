# Departments of a unit, in a tree, with zero or more managers (RN-04-020 to RN-04-025,
# D-202, D-203).
class CreateDepartments < ActiveRecord::Migration[8.1]
  def change
    create_table :departments do |t|
      t.references :company, null: false, foreign_key: true
      t.references :unit, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :departments }
      t.string :name, null: false
      t.string :status, null: false, default: "active"
      t.timestamps
    end

    create_table :department_managers do |t|
      t.references :company, null: false, foreign_key: true
      t.references :department, null: false, foreign_key: { on_delete: :cascade }
      t.references :membership, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :department_managers, %i[department_id membership_id], unique: true
  end
end
