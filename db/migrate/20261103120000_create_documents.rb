# The documents' folder (spec 08, block 08a, D-642): the types, the platform's (without a
# company) and the company's ones in the same table (D-270), what each company changes on
# the platform's (P-08-04), the periodicity by position (D-272), the documents of each
# person and their versions (RN-08-020). A version's files and its single PDF are Active
# Storage attachments, scanned through file_scans (D-640).
class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :document_types, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, foreign_key: true
      # Only the platform's types have a code, used by the seed and the other specs.
      t.string :code
      t.string :name, null: false
      t.text :description
      t.string :category, null: false
      t.boolean :internal, null: false, default: false
      t.boolean :requires_acknowledgment, null: false, default: false
      t.string :expiration_rule, null: false, default: "none"
      t.integer :expiration_months
      t.integer :max_age_days
      t.integer :alert_days, null: false, default: 30
      t.integer :max_files, null: false, default: 1
      t.string :status, null: false, default: "active"
      t.timestamps
    end
    add_index :document_types, :code, unique: true, where: "company_id IS NULL", name: "index_document_types_platform_code"

    create_table :company_document_type_settings, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, index: false, foreign_key: true
      t.references :document_type, type: :uuid, null: false, foreign_key: true
      t.boolean :enabled, null: false, default: true
      t.integer :alert_days
      t.timestamps
    end
    add_index :company_document_type_settings, %i[company_id document_type_id], unique: true,
      name: "index_company_document_type_settings_unique"

    create_table :position_document_expirations, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :position, type: :uuid, null: false, index: false, foreign_key: true
      t.references :document_type, type: :uuid, null: false, foreign_key: true
      t.integer :expiration_months, null: false
      t.timestamps
    end
    add_index :position_document_expirations, %i[position_id document_type_id], unique: true,
      name: "index_position_document_expirations_unique"

    create_table :documents, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, index: false, foreign_key: true
      t.references :worker_profile, type: :uuid, null: false, index: false, foreign_key: true
      t.references :document_type, type: :uuid, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.uuid :current_version_id
      t.date :expires_on
      t.string :source, null: false, default: "hr"
      t.references :source_ref, type: :uuid, polymorphic: true
      # The dependent's certificate and the bank account's proof (RN-04-043, P-04-17, D-604).
      t.references :dependent, type: :uuid, foreign_key: true
      t.references :bank_account, type: :uuid, foreign_key: true
      t.datetime :deleted_at
      t.references :deleted_by, type: :uuid, foreign_key: { to_table: :users }
      t.text :delete_reason
      t.timestamps
    end
    add_index :documents, %i[company_id worker_profile_id], name: "index_documents_folder"

    create_table :document_versions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :document, type: :uuid, null: false, index: false, foreign_key: true
      t.integer :number, null: false
      t.string :status, null: false, default: "scanning"
      t.string :sha256
      t.references :uploaded_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.datetime :uploaded_at, null: false
      t.references :reviewed_by, type: :uuid, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.string :correction_reason
      t.text :correction_note
      t.date :issued_on
      t.date :valid_until
      t.timestamps
    end
    add_index :document_versions, %i[document_id number], unique: true
    # The review queue (D-642).
    add_index :document_versions, %i[company_id status], name: "index_document_versions_queue"

    # Both tables were just created, empty, in this migration: nothing to block.
    safety_assured { add_foreign_key :documents, :document_versions, column: :current_version_id }
    add_index :documents, :current_version_id
  end
end
