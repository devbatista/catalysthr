# Companies assigned to a consultant of the partner (D-052, spec 02, section 7). The
# consultant reaches only these, inside the partner's subdomain (RN-01-011).
class CreatePartnerMembershipCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :partner_membership_companies do |t|
      t.references :membership, null: false, foreign_key: true, index: false
      t.references :company, null: false, foreign_key: true
      t.timestamps
    end
    add_index :partner_membership_companies, %i[membership_id company_id], unique: true,
      name: "index_partner_membership_companies_on_membership_and_company"
  end
end
