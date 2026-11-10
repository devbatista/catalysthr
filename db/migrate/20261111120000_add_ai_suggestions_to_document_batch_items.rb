# Block 14c of spec 14 (D-670, D-672): the AI's suggestions on a batch's file. The type comes
# with the AI's confidence; the person is found by the system, by the CPF or by a similar name
# (RN-14-031), with pg_trgm and unaccent, both PostgreSQL's own. The candidates keep only the
# person's id and the score, never a name or a CPF.
class AddAiSuggestionsToDocumentBatchItems < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pg_trgm"
    enable_extension "unaccent"

    add_column :document_batch_items, :type_confidence, :string
    add_column :document_batch_items, :person_match, :string
    add_column :document_batch_items, :person_candidates, :jsonb, null: false, default: []
  end
end
