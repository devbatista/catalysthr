# People and their sign-in data (spec 02, section 7; RN-02-001, RN-02-002, P-02-01).
# MFA columns come with the MFA (RN-02-040, P-02-35).
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      # Deterministic encryption, so it can be searched and kept unique (D-086, P-05-02).
      t.string :cpf, null: false
      t.string :email
      t.string :mobile_phone
      t.date :birth_date
      t.string :status, null: false, default: "active"
      t.string :platform_role

      # Devise: password, recovery, lockout and sign-in tracking.
      t.string :encrypted_password, null: false, default: ""
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.integer :failed_attempts, null: false, default: 0
      t.string :unlock_token
      t.datetime :locked_at
      t.integer :sign_in_count, null: false, default: 0
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string :current_sign_in_ip
      t.string :last_sign_in_ip

      t.timestamps
    end

    add_index :users, :cpf, unique: true
    add_index :users, :email, unique: true, where: "email IS NOT NULL"
    add_index :users, :reset_password_token, unique: true
    add_index :users, :unlock_token, unique: true
    add_index :users, :platform_role, where: "platform_role IS NOT NULL"
  end
end
