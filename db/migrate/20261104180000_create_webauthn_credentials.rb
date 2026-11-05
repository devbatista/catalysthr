# Block 16c of spec 16 (D-645): the passkeys. Only the public key and the counter stay on
# the server (RN-16-077). A removed passkey keeps its line, with removed_at, for the audit.
# The user's handle is random, so nothing of the person goes to the authenticator as the
# account's identifier.
class CreateWebauthnCredentials < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :users, :webauthn_handle, :string
    add_index :users, :webauthn_handle, unique: true, algorithm: :concurrently

    create_table :webauthn_credentials, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :rp_id, null: false
      t.string :external_id, null: false
      t.text :public_key, null: false
      t.bigint :sign_count, null: false, default: 0
      t.string :nickname, null: false
      t.string :transports, array: true, null: false, default: []
      t.string :aaguid
      t.datetime :last_used_at
      t.datetime :removed_at
      t.timestamps
      t.index %i[rp_id external_id], unique: true
    end
  end
end
