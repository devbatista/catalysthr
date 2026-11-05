# Block 07a of spec 07 (D-648): the admission that links the employment, the process, the
# eSocial and the ASO (P-07-18), the step of each item (RN-07-001), the models that are the
# default of an employment kind (RN-07-013), the documents a position requires (RN-04-030,
# RN-06-037) and the company's accounting step (D-258). The items already there take their
# step from their kind; only the admission's use it.
class CreateAdmissions < ActiveRecord::Migration[8.1]
  def stage_of_kind(table)
    <<~SQL.squish
      CASE #{table}.kind WHEN 'forward' THEN 'accounting'
        WHEN 'document' THEN 'documents' WHEN 'form' THEN 'documents' WHEN 'acknowledgement' THEN 'documents'
        ELSE 'hr_review' END
    SQL
  end

  def up
    create_table :admissions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :employment, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.references :process_instance, type: :uuid, null: false, foreign_key: true
      t.string :source, null: false, default: "manual"
      t.string :source_ref
      t.datetime :invite_released_at
      t.references :invite_released_by, type: :uuid, foreign_key: { to_table: :users }
      t.string :esocial_status, null: false, default: "not_sent"
      t.uuid :esocial_event_id
      t.string :aso_status, null: false, default: "missing"
      t.datetime :completed_at
      t.references :completed_by, type: :uuid, foreign_key: { to_table: :users }
      t.datetime :cancelled_at
      t.string :cancel_reason
      t.text :cancel_note
      t.timestamps
    end

    create_table :position_required_document_types, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :position, type: :uuid, null: false, foreign_key: true, index: false
      t.references :document_type, type: :uuid, null: false, foreign_key: true
      t.timestamps
      t.index %i[position_id document_type_id], unique: true, name: "index_position_required_document_types_unique"
    end

    add_column :process_template_items, :stage, :string
    add_column :process_items, :stage, :string
    add_column :process_templates, :default_employment_kinds, :string, array: true, null: false, default: []
    add_column :companies, :uses_accounting_step, :boolean, null: false, default: false

    safety_assured do
      execute <<~SQL.squish
        UPDATE process_template_items SET stage = #{stage_of_kind("process_template_items")}
        FROM process_templates
        WHERE process_templates.id = process_template_items.process_template_id AND process_templates.kind = 'admission'
      SQL
      execute <<~SQL.squish
        UPDATE process_items SET stage = #{stage_of_kind("process_items")}
        FROM process_instances
        WHERE process_instances.id = process_items.process_instance_id AND process_instances.kind = 'admission'
      SQL
    end
  end

  def down
    remove_column :companies, :uses_accounting_step
    remove_column :process_templates, :default_employment_kinds
    remove_column :process_items, :stage
    remove_column :process_template_items, :stage
    drop_table :position_required_document_types
    drop_table :admissions
  end
end
