# The official CBO occupations, global and without a tenant (RN-04-031, P-04-13).
# Codes that leave the official table stay, inactive, because old positions may use them.
class CreateCboOccupations < ActiveRecord::Migration[8.1]
  def change
    create_table :cbo_occupations do |t|
      t.string :code, null: false, limit: 6
      t.string :title, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :cbo_occupations, :code, unique: true
  end
end
