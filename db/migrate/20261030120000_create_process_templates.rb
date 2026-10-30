# Models of process (spec 06, RN-06-001 to RN-06-042, D-639): the CatalystHR library and
# the partner's models have no company; the company's have it, for acts_as_tenant. One
# table each for models and items, read by two models each (D-639), so neither reaches
# another company. A position may point to its own admission model (D-204, RN-06-003).
class CreateProcessTemplates < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    create_table :process_templates, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, foreign_key: true
      t.references :partner, type: :uuid, foreign_key: true
      t.string :kind, null: false
      t.string :name, null: false
      t.text :description
      t.string :status, null: false, default: "draft"
      t.boolean :is_default, null: false, default: false
      # Where the copy came from, for information only (D-232).
      t.references :source_template, type: :uuid, foreign_key: { to_table: :process_templates, on_delete: :nullify }
      # The onboarding that starts when the admission ends (RN-06-004).
      t.references :onboarding_template, type: :uuid, foreign_key: { to_table: :process_templates, on_delete: :nullify }
      t.timestamps
    end
    add_check_constraint :process_templates, "company_id IS NULL OR partner_id IS NULL", name: "process_templates_one_owner"
    # One default per kind in the company (RN-06-003).
    add_index :process_templates, %i[company_id kind], unique: true, where: "is_default", name: "index_process_templates_default"

    create_table :process_template_items, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, foreign_key: true
      t.references :process_template, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer :position, null: false
      t.string :kind, null: false
      t.string :title, null: false
      t.text :instructions
      t.boolean :required, null: false, default: true
      t.string :responsible_role, null: false
      t.string :due_anchor
      t.integer :due_offset_days
      t.boolean :due_business_days, null: false, default: false
      t.jsonb :conditions, null: false, default: {}
      t.jsonb :config, null: false, default: {}
      t.uuid :depends_on_item_ids, array: true, null: false, default: []
      t.timestamps
    end
    add_index :process_template_items, %i[process_template_id position]

    add_reference :positions, :admission_template, type: :uuid, index: { algorithm: :concurrently }
    add_foreign_key :positions, :process_templates, column: :admission_template_id, on_delete: :nullify, validate: false
  end
end
