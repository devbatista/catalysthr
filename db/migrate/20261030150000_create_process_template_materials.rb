# The PDF of an acknowledgement item, one row per version (spec 06, RN-06-060, P-06-17,
# D-640), read by two models like the items (D-639). Versions outlive the item, so an
# acceptance keeps the version it read. The virus scan of each Active Storage file
# (P-05-30, RN-20-015) has its own table, without a company, for specs 08 and 21 too.
class CreateProcessTemplateMaterials < ActiveRecord::Migration[8.1]
  def change
    create_table :file_scans, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :blob, type: :uuid, null: false, index: { unique: true },
        foreign_key: { to_table: :active_storage_blobs, on_delete: :cascade }
      t.string :status, null: false, default: "scanning"
      # The name of the signature found, never the file's.
      t.string :signature
      t.datetime :attempted_at
      t.datetime :scanned_at
      t.timestamps
    end
    # The hourly job looks for what is still scanning (D-640).
    add_index :file_scans, :created_at, where: "status = 'scanning'", name: "index_file_scans_scanning"

    create_table :process_template_materials, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, foreign_key: true
      t.references :process_template_item, type: :uuid, index: false, foreign_key: { on_delete: :nullify }
      t.integer :version, null: false
      t.references :uploaded_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :process_template_materials, %i[process_template_item_id version], unique: true,
      name: "index_process_template_materials_version"
  end
end
