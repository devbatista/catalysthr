# Block 17a of spec 17 (D-657, D-658): the HR panel's "Atividade recente" (RN-17-011). Each
# line is a happening of the company, already written as the panel shows it, without
# sensitive data. The unit, the client and the module say who sees it (RN-17-001,
# RN-17-005, RN-17-014). Lines are deleted 90 days later (D-657).
class CreateActivityEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :activity_events, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: false
      t.references :unit, type: :uuid, foreign_key: true
      t.references :department, type: :uuid, foreign_key: true
      t.references :allocation_client, type: :uuid, foreign_key: true
      t.string :module_code, null: false
      t.string :kind, null: false
      t.string :actor_name
      t.text :text, null: false
      t.string :url
      t.datetime :occurred_at, null: false
      t.index %i[company_id occurred_at]
      t.index :occurred_at
    end
  end
end
