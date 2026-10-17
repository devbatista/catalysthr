# The company's positions, valid in every unit (RN-04-030 to RN-04-032, D-204). Amounts
# in cents. The admission template (spec 06) and the required documents (spec 08) come
# with those specs.
class CreatePositions < ActiveRecord::Migration[8.1]
  def change
    create_table :positions do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.string :cbo_code, null: false, limit: 6
      t.integer :salary_min_cents
      t.integer :salary_max_cents
      t.text :description
      t.text :requirements
      t.string :status, null: false, default: "active"
      t.timestamps
    end
  end
end
