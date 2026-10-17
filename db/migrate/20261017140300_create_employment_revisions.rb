# The employment's conditions from a date on (RN-04-060 to RN-04-064, P-04-02, D-207). The
# salary is encrypted, in cents (D-086). Revisions in force are never changed: a mistake
# is corrected by a new one (D-603). The work schedule comes with spec 11 and the
# allocation client with block 4d.
class CreateEmploymentRevisions < ActiveRecord::Migration[8.1]
  def change
    create_table :employment_revisions do |t|
      t.references :company, null: false, foreign_key: true
      t.references :employment, null: false, foreign_key: true
      t.date :effective_on, null: false
      t.references :position, null: false, foreign_key: true
      t.string :cbo_code, null: false, limit: 6
      t.text :salary_cents
      t.string :salary_unit, null: false
      t.text :variable_salary_description
      t.references :unit, null: false, foreign_key: true
      t.references :department, foreign_key: true
      t.decimal :weekly_hours, precision: 4, scale: 2
      t.string :reason, null: false
      t.text :justification
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :employment_revisions, %i[employment_id effective_on id]
  end
end
