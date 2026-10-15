# The link between a person and a company, partner or accounting firm, with one or
# more roles (spec 02, section 7; D-050 to D-052, P-02-36). Invitation columns come
# with the invitation (RN-02-010), and released units and modules with spec 03.
class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, polymorphic: true, null: false
      t.string :roles, array: true, null: false, default: []
      t.string :status, null: false, default: "invited"

      t.timestamps
    end

    add_index :memberships, [ :user_id, :organization_type, :organization_id ], unique: true,
      name: "index_memberships_on_user_and_organization"
  end
end
