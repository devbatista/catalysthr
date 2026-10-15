# Versioned terms of use and privacy policy (D-577, D-578, D-579) and the record of
# every acceptance and consent (RN-02-015, P-02-10).
class CreateLegalDocumentsAndConsents < ActiveRecord::Migration[8.1]
  def change
    create_table :legal_documents do |t|
      # Without a brand: the CatalystHR texts, used by brands without their own.
      t.references :brand, foreign_key: true
      t.string :kind, null: false
      t.integer :version, null: false
      t.text :body, null: false
      t.datetime :published_at, null: false
      t.references :published_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :legal_documents, [ :brand_id, :kind, :version ], unique: true, nulls_not_distinct: true,
      name: "index_legal_documents_on_brand_kind_and_version"

    create_table :consents do |t|
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false
      # Brand for the terms and the privacy policy; Company for biometrics and WhatsApp.
      t.references :scope, polymorphic: true, null: false
      t.references :legal_document, foreign_key: true
      t.integer :document_version, null: false
      t.boolean :granted, null: false
      t.string :ip
      t.string :user_agent
      t.datetime :decided_at, null: false
      t.datetime :revoked_at

      t.timestamps
    end
  end
end
