# The person's dependents in the company (RN-04-043, D-208). The CPF is encrypted (D-086).
# A dependent who leaves is ended, never deleted (D-604). The certificate comes with the
# documents folder (spec 08).
class CreateDependents < ActiveRecord::Migration[8.1]
  def change
    create_table :dependents do |t|
      t.references :company, null: false, foreign_key: true
      t.references :worker_profile, null: false, foreign_key: true
      t.string :name, null: false
      t.text :cpf
      t.date :birth_date, null: false
      t.string :sex
      t.string :relationship_type, null: false
      t.boolean :irrf, null: false, default: false
      t.boolean :family_allowance, null: false, default: false
      t.boolean :incapable, null: false, default: false
      t.string :status, null: false, default: "active"
      t.date :ended_on
      t.timestamps
    end
  end
end
