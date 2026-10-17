# The person's emergency contacts, one or more (RN-04-041).
class CreateEmergencyContacts < ActiveRecord::Migration[8.1]
  def change
    create_table :emergency_contacts do |t|
      t.references :company, null: false, foreign_key: true
      t.references :worker_profile, null: false, foreign_key: true
      t.string :name, null: false
      t.string :relationship
      t.string :phone, null: false
      t.timestamps
    end
  end
end
