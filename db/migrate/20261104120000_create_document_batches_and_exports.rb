# Block 08c of spec 08 (D-644): the HR's batches, with one item per file confirmed by hand
# until spec 14 suggests the type and the person (D-642, RN-08-060); the folder's ZIP for
# who asked it, for 24 hours (RN-08-082); and when a deleted document's files left the
# storage, after the 30 days (RN-08-083).
class CreateDocumentBatchesAndExports < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :documents, :purged_at, :datetime
    add_index :documents, :deleted_at, where: "deleted_at IS NOT NULL AND purged_at IS NULL", name: "index_documents_to_purge",
      algorithm: :concurrently

    create_table :document_batches, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :uploaded_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "awaiting_confirmation"
      t.datetime :expires_at, null: false
      t.datetime :expiry_notified_at
      t.timestamps
    end

    create_table :document_batch_items, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :document_batch, type: :uuid, null: false, foreign_key: true
      # The AI's suggestions come with spec 14 (D-642).
      t.references :suggested_type, type: :uuid, foreign_key: { to_table: :document_types }
      t.references :suggested_worker_profile, type: :uuid, foreign_key: { to_table: :worker_profiles }
      t.decimal :confidence, precision: 4, scale: 3
      t.references :confirmed_type, type: :uuid, foreign_key: { to_table: :document_types }
      t.references :confirmed_worker_profile, type: :uuid, foreign_key: { to_table: :worker_profiles }
      t.string :status, null: false, default: "pending"
      t.references :document, type: :uuid, foreign_key: true
      t.timestamps
    end

    create_table :document_folder_exports, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :worker_profile, type: :uuid, null: false, foreign_key: true
      t.references :requested_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "queued"
      t.integer :documents_count
      t.datetime :expires_at
      t.timestamps
    end
  end
end
