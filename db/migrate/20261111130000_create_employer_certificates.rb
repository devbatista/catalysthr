# The employer's A1 certificate (spec 13, RN-13-020 to RN-13-022, D-075, D-673): the .pfx and
# its password sealed with a data key of the A1's KMS key (envelope encryption, because KMS
# itself seals at most 4 KB), the holder and the validity read from it, and the notices of 30,
# 15 and 5 days already sent. A replaced or removed one keeps only its metadata (D-673).
class CreateEmployerCertificates < ActiveRecord::Migration[8.1]
  def change
    create_table :employer_certificates, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: false
      t.string :owner_kind, null: false
      t.string :status, null: false, default: "active"
      t.string :holder_name
      t.string :holder_document
      t.datetime :valid_from, null: false
      t.datetime :valid_to, null: false
      t.string :kms_key_id
      t.text :sealed_key
      t.text :sealed_pfx
      t.text :sealed_password
      t.integer :alerted_days
      t.references :uploaded_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.references :removed_by, type: :uuid, foreign_key: { to_table: :users }
      t.datetime :replaced_at
      t.datetime :removed_at
      t.timestamps
    end
    add_index :employer_certificates, :company_id, unique: true, where: "status = 'active'", name: "index_employer_certificates_one_active"
    add_index :employer_certificates, %i[company_id created_at]
    add_index :employer_certificates, :valid_to, where: "status = 'active'"
  end
end
