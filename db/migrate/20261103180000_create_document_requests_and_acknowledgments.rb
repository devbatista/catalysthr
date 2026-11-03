# Block 08b of spec 08 (D-643): the expirations' notice, sent once per date (RN-08-031);
# the HR's requests, with one target per person (D-278); and the publications asking for
# an acknowledgment, with one record per person (D-279). The witnesses of a refusal carry
# CPFs, so they are encrypted (D-086).
class CreateDocumentRequestsAndAcknowledgments < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # The expires_on whose notice already went, so the daily job never repeats it.
    add_column :documents, :expiration_alerted_on, :date
    add_index :documents, %i[company_id expires_on], where: "expires_on IS NOT NULL AND deleted_at IS NULL",
      name: "index_documents_expiring", algorithm: :concurrently

    create_table :document_requests, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :document_type, type: :uuid, null: false, foreign_key: true
      t.references :requested_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.text :message
      t.date :due_on
      t.jsonb :audience_filter, null: false, default: {}
      t.timestamps
    end

    create_table :document_request_targets, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :document_request, type: :uuid, null: false, index: false, foreign_key: true
      t.references :worker_profile, type: :uuid, null: false, foreign_key: true
      t.references :document, type: :uuid, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.timestamps
    end
    add_index :document_request_targets, %i[document_request_id worker_profile_id], unique: true,
      name: "index_document_request_targets_unique"

    create_table :document_publications, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :document_type, type: :uuid, null: false, foreign_key: true
      t.references :published_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :message
      t.date :due_on, null: false
      t.jsonb :audience_filter, null: false, default: {}
      t.timestamps
    end

    create_table :acknowledgments, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :document_publication, type: :uuid, foreign_key: true
      t.references :document, type: :uuid, null: false, foreign_key: true
      t.references :document_version, type: :uuid, null: false, foreign_key: true
      t.references :worker_profile, type: :uuid, null: false, foreign_key: true
      t.string :status, null: false, default: "awaiting"
      t.date :due_on, null: false
      t.datetime :acknowledged_at
      t.string :ip
      t.string :user_agent
      t.text :comment
      # The file's hash at the moment of the acknowledgment (RN-08-051).
      t.string :sha256
      t.text :refused_note
      t.text :witnesses
      t.references :recorded_by, type: :uuid, foreign_key: { to_table: :users }
      t.datetime :recorded_at
      t.timestamps
    end
  end
end
