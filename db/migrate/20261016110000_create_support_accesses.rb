# The support's entries into a direct company (D-581, P-03-02): who, which company, why,
# and when it started and ended. The one-time token opens the company's subdomain, as in
# the impersonate (RN-02-082); only its digest is kept.
class CreateSupportAccesses < ActiveRecord::Migration[8.1]
  def change
    create_table :support_accesses do |t|
      t.references :support_user, null: false, foreign_key: { to_table: :users }
      t.references :company, null: false, foreign_key: true
      t.references :brand, null: false, foreign_key: true
      t.text :reason, null: false
      t.string :token_digest, index: { unique: true }
      t.datetime :token_expires_at, null: false
      t.datetime :started_at
      t.datetime :ended_at
      t.string :ended_reason
      t.timestamps
    end
  end
end
