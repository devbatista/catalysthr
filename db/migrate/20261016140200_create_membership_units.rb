# The units an HR analyst works on: the U scope (spec 03, D-142).
class CreateMembershipUnits < ActiveRecord::Migration[8.1]
  def change
    create_table :membership_units do |t|
      t.references :company, null: false, foreign_key: true
      t.references :membership, null: false, foreign_key: { on_delete: :cascade }
      t.references :unit, null: false, foreign_key: true
      t.timestamps
    end
    add_index :membership_units, %i[membership_id unit_id], unique: true
  end
end
