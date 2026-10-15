# Partners and companies (spec 01, section 7; D-120, D-121).
# The company is the tenant (D-151). Lifecycle statuses come with spec 19.
class CreatePartnersAndCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :partners do |t|
      t.string :name, null: false
      t.string :legal_name, null: false
      t.string :cnpj, null: false, limit: 14
      t.timestamps
    end
    add_index :partners, :cnpj, unique: true

    create_table :companies do |t|
      t.references :partner, foreign_key: true
      t.string :name, null: false
      t.string :legal_name, null: false
      t.string :cnpj, null: false, limit: 14
      # Only for companies with a partner (RN-01-034, D-165)
      t.string :brand_display_mode
      t.timestamps
    end
    add_index :companies, :cnpj, unique: true
  end
end
