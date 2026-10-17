# A work contract of the person in the company; a record may have several, at the same
# time or one after another (RN-04-050 to RN-04-055, D-176, D-205). The registration
# number is unique among all the company's employments, ended ones included (RN-04-052,
# P-04-18, CA-04-010). The fields of each kind go in details (P-04-27).
class CreateEmployments < ActiveRecord::Migration[8.1]
  def change
    create_table :employments do |t|
      t.references :company, null: false, foreign_key: true
      t.references :worker_profile, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :category
      t.string :registration_number, null: false
      t.string :status, null: false, default: "active"
      t.date :started_on, null: false
      t.date :ended_on
      t.string :termination_reason
      t.jsonb :details, null: false, default: {}
      t.timestamps
    end
    add_index :employments, %i[company_id registration_number], unique: true
  end
end
