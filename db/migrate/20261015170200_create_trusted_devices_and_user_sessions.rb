# Remembered devices for 30 days (RN-02-043, P-02-21) and the open sessions, checked on
# every request (RN-02-053, RN-02-063, D-576). Only the tokens' digests are stored.
class CreateTrustedDevicesAndUserSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :trusted_devices do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false, index: { unique: true }
      t.string :user_agent
      t.datetime :last_used_at
      t.datetime :expires_at, null: false
      t.datetime :revoked_at

      t.timestamps
    end

    create_table :user_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false, index: { unique: true }
      t.string :area, null: false
      t.references :brand, foreign_key: true
      t.string :user_agent
      t.string :ip
      t.datetime :last_seen_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.string :revoked_reason

      t.timestamps
    end

    add_index :user_sessions, :expires_at
    add_index :trusted_devices, :expires_at
  end
end
