# The company's clients where its people work allocated, and their managers (RN-04-091,
# RN-04-094, D-570).
class CreateAllocationClients < ActiveRecord::Migration[8.1]
  def change
    create_table :allocation_clients do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.string :document_type
      t.string :document
      t.string :status, null: false, default: "active"
      t.timestamps
    end
    add_index :allocation_clients, %i[company_id document], unique: true, where: "document IS NOT NULL"

    create_table :allocation_client_managers do |t|
      t.references :company, null: false, foreign_key: true
      t.references :allocation_client, null: false, foreign_key: { on_delete: :cascade }
      t.references :membership, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :allocation_client_managers, %i[allocation_client_id membership_id], unique: true
  end
end
