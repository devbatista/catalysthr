# Accounting firms and their links to the companies they serve (spec 02, section 7;
# D-170, D-171, RN-02-070 to RN-02-073). A company has at most one pending or active
# link (D-589).
class CreateAccountingFirms < ActiveRecord::Migration[8.1]
  def change
    create_table :accounting_firms do |t|
      t.string :name, null: false
      t.string :cnpj, null: false, index: { unique: true }
      t.string :status, null: false, default: "active"
      t.timestamps
    end

    create_table :accounting_firm_companies do |t|
      t.references :accounting_firm, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true, index: false
      t.string :status, null: false, default: "pending"
      t.references :linked_by, foreign_key: { to_table: :users }
      t.datetime :accepted_at
      t.datetime :ended_at
      t.timestamps
    end
    add_index :accounting_firm_companies, :company_id, unique: true, where: "status IN ('pending', 'active')",
      name: "index_accounting_firm_companies_one_open_per_company"
    add_index :accounting_firm_companies, %i[company_id status]
  end
end
