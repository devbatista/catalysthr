# Block 07c of spec 07 (D-650): the models of contracts and terms and what is generated from
# them (RN-07-040 to RN-07-043, D-253). The PDF stays in the process, one per employment and
# model; the signed one goes to the folder, as the platform's new "Contrato assinado".
class CreateDocumentTemplates < ActiveRecord::Migration[8.1]
  class MigrationDocumentType < ActiveRecord::Base
    self.table_name = "document_types"
  end

  def up
    create_table :document_templates, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.string :employment_kinds, array: true, null: false, default: []
      t.text :body, null: false
      t.string :status, null: false, default: "active"
      t.timestamps
    end

    create_table :generated_documents, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :employment, type: :uuid, null: false, foreign_key: true, index: false
      t.references :document_template, type: :uuid, null: false, foreign_key: true
      t.string :status, null: false, default: "generating"
      t.references :generated_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.datetime :generated_at
      t.string :missing_variables, array: true, null: false, default: []
      t.references :signed_document, type: :uuid, foreign_key: { to_table: :documents }
      t.timestamps
      t.index %i[employment_id document_template_id], unique: true, name: "index_generated_documents_unique"
    end

    self.class.load_signed_contract
  end

  def down
    drop_table :generated_documents
    drop_table :document_templates
    MigrationDocumentType.where(code: "signed_contract", company_id: nil).delete_all
  end

  # Also for the test database, built from the schema.
  def self.load_signed_contract
    return if MigrationDocumentType.exists?(code: "signed_contract", company_id: nil)

    MigrationDocumentType.create!(code: "signed_contract", name: "Contrato assinado", category: "admission", max_files: 5,
      expiration_rule: "none")
  end
end
