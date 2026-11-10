# Block 14b of spec 14 (D-670): the reading of a document by the AI. The fields read carry
# personal data, so they are kept encrypted and out of the versions (D-086); the system's checks
# keep only the result of each one, never a value (RN-14-022).
class CreateAiExtractions < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_extractions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: false
      t.string :subject_type, null: false
      t.uuid :subject_id, null: false
      t.string :profile_code
      t.string :status, null: false, default: "queued"
      t.string :detected_type_code
      t.text :fields
      t.jsonb :checks, null: false, default: {}
      t.jsonb :flags, null: false, default: []
      t.references :ai_request, type: :uuid, foreign_key: true
      t.integer :attempts, null: false, default: 0
      t.string :failed_reason
      t.timestamps
    end
    add_index :ai_extractions, %i[subject_type subject_id], unique: true
    add_index :ai_extractions, %i[company_id created_at]

    # The fields the AI reads from each platform type (RN-08-001, RN-14-021); the company's
    # types have none (RN-14-025).
    add_column :document_types, :ai_extraction_profile, :string
  end
end
