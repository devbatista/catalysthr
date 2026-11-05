# Block 07b of spec 07 (D-649): the answers of a form item (RN-06-030, RN-06-031). They are
# encrypted as a whole and stay out of the versions (D-086): the table has no PaperTrail.
# Once applied, only what stays in the process remains; the rest lives in the record.
class CreateProcessFormResponses < ActiveRecord::Migration[8.1]
  def change
    create_table :process_form_responses, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :process_item, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.text :answers
      t.datetime :submitted_at
      t.references :submitted_by, type: :uuid, foreign_key: { to_table: :users }
      t.text :correction_reason
      t.datetime :applied_at
      t.references :applied_by, type: :uuid, foreign_key: { to_table: :users }
      t.string :applied_fields, array: true, null: false, default: []
      t.timestamps
    end
  end
end
