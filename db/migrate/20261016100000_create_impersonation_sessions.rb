# Impersonate sessions (spec 02, section 7, P-02-34): who saw the system as whom, why,
# at which brand and for how long (RN-02-080 to RN-02-088). The one-time token opens
# the brand's subdomain (RN-02-082); only its digest is kept.
class CreateImpersonationSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :impersonation_sessions do |t|
      t.references :impersonator, null: false, foreign_key: { to_table: :users }
      t.references :impersonated_user, null: false, foreign_key: { to_table: :users }
      t.references :brand, null: false, foreign_key: true
      t.text :reason, null: false
      t.string :token_digest, index: { unique: true }
      t.datetime :token_expires_at, null: false
      t.datetime :started_at
      t.datetime :expires_at
      t.datetime :ended_at
      t.string :ended_reason
      t.timestamps
    end
  end
end
