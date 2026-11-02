# Processes (spec 06, RN-06-050 to RN-06-053, D-641): a copy of a company's model for one
# subject, with its items already assigned, dated and blocked, the dependencies between
# them and the history of each change (RN-06-051).
class CreateProcessInstances < ActiveRecord::Migration[8.1]
  def change
    create_table :process_instances, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      # The model it came from; archiving or editing it never touches the process (D-091).
      t.references :process_template, type: :uuid, foreign_key: { on_delete: :nullify }
      t.string :kind, null: false
      t.string :subject_type, null: false
      t.uuid :subject_id, null: false
      t.string :status, null: false, default: "open"
      t.jsonb :anchor_dates, null: false, default: {}
      # The employment's kind, position, unit and client at the start (RN-06-036).
      t.jsonb :subject_snapshot, null: false, default: {}
      # The person's unit at the start: the HR of the unit sees the process (D-641), and
      # the business days follow its holidays (RN-06-026).
      t.references :unit, type: :uuid, foreign_key: true
      t.string :completion_mode, null: false, default: "confirm"
      t.references :started_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.datetime :completed_at
      t.references :completed_by, type: :uuid, foreign_key: { to_table: :users }
      t.datetime :cancelled_at
      t.references :cancelled_by, type: :uuid, foreign_key: { to_table: :users }
      t.text :cancel_reason
      t.timestamps
    end
    add_index :process_instances, %i[subject_type subject_id]

    create_table :process_items, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :process_instance, type: :uuid, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :source_template_item, type: :uuid, foreign_key: { to_table: :process_template_items, on_delete: :nullify }
      t.integer :position, null: false
      t.string :kind, null: false
      t.string :title, null: false
      t.text :instructions
      t.boolean :required, null: false, default: true
      t.string :status, null: false
      t.string :responsible_role, null: false
      t.uuid :responsible_membership_ids, array: true, null: false, default: []
      # The role had nobody, so the item went to the HR (RN-06-022).
      t.boolean :responsible_fallback, null: false, default: false
      t.string :due_anchor
      t.integer :due_offset_days
      t.boolean :due_business_days, null: false, default: false
      t.date :due_on
      t.boolean :due_manually_set, null: false, default: false
      t.date :overdue_notified_on
      t.jsonb :config, null: false, default: {}
      t.jsonb :result, null: false, default: {}
      t.references :completed_by, type: :uuid, foreign_key: { to_table: :users }
      t.datetime :completed_at
      t.text :skipped_reason
      t.timestamps
    end
    add_index :process_items, %i[process_instance_id position]
    add_index :process_items, :responsible_membership_ids, using: :gin
    # The daily job reads the open items by their date (RN-06-028).
    add_index :process_items, :due_on, where: "status IN ('blocked', 'pending')", name: "index_process_items_open_due_on"

    create_table :process_item_dependencies, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :item, type: :uuid, null: false, index: false, foreign_key: { to_table: :process_items, on_delete: :cascade }
      t.references :depends_on_item, type: :uuid, null: false, foreign_key: { to_table: :process_items, on_delete: :cascade }
      t.timestamps
    end
    add_index :process_item_dependencies, %i[item_id depends_on_item_id], unique: true

    create_table :process_events, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :process_instance, type: :uuid, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :process_item, type: :uuid, foreign_key: { on_delete: :nullify }
      t.string :action, null: false
      # Nobody when the system did it, such as unblocking an item.
      t.references :actor, type: :uuid, foreign_key: { to_table: :users }
      t.jsonb :details, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :process_events, %i[process_instance_id created_at]
  end
end
