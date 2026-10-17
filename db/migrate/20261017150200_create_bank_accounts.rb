# Where the person is paid: a bank account or a PIX key, one of them primary (RN-04-044,
# D-208). The account number and the PIX key are encrypted (D-086). Accounts are ended,
# never deleted; a new primary ends the previous one (D-604). The ownership is declared
# by the HR until the proof comes with spec 08 (P-04-17).
class CreateBankAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :bank_accounts do |t|
      t.references :company, null: false, foreign_key: true
      t.references :worker_profile, null: false, foreign_key: true
      t.string :bank_code
      t.string :branch
      t.text :account_number
      t.string :account_type
      t.string :pix_key_type
      t.text :pix_key
      t.boolean :primary, null: false, default: false
      t.string :status, null: false, default: "active"
      t.date :ended_on
      t.references :declared_by, null: false, foreign_key: { to_table: :users }
      t.datetime :declared_at, null: false
      t.timestamps
    end
    add_index :bank_accounts, :worker_profile_id, unique: true, where: "\"primary\" AND status = 'active'",
      name: "index_bank_accounts_one_primary_per_profile"
  end
end
