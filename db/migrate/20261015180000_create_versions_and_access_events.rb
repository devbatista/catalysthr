# Audit (spec 05, section 9): the change trail (PaperTrail, D-084) and the access events
# (D-085). Sensitive values never enter the versions; sensitive_fields records only the
# names of the sensitive fields that changed (RN-05-011).
class CreateVersionsAndAccessEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :versions do |t|
      t.string :item_type, null: false
      t.bigint :item_id, null: false
      t.string :event, null: false
      t.string :whodunnit
      t.jsonb :object
      t.jsonb :object_changes
      t.string :sensitive_fields, array: true, null: false, default: []
      t.bigint :impersonator_id
      t.bigint :company_id
      t.string :ip
      t.string :request_id
      t.datetime :created_at, null: false
    end

    add_index :versions, %i[item_type item_id]
    add_index :versions, :company_id

    create_table :access_events do |t|
      t.references :company, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :impersonator, foreign_key: { to_table: :users }
      t.string :kind, null: false
      t.string :action, null: false
      t.references :subject, polymorphic: true
      t.string :field
      t.string :ip
      t.string :user_agent
      t.string :request_id
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :access_events, %i[company_id created_at]
    add_index :access_events, %i[user_id created_at]
  end
end
