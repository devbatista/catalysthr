# MFA with an authenticator app and recovery codes (RN-02-040 to RN-02-042, P-02-35).
# The secret is encrypted by the gem (Active Record Encryption); the codes are hashes.
class AddTwoFactorToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :otp_secret, :string
    add_column :users, :consumed_timestep, :integer
    add_column :users, :otp_required_for_login, :boolean, null: false, default: false
    add_column :users, :otp_backup_codes, :string, array: true
  end
end
