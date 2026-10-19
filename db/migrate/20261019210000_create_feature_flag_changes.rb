# Who turned each feature flag on or off, and when, from the admin's screen (D-617).
class CreateFeatureFlagChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :feature_flag_changes, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :flag, null: false
      t.string :action, null: false
      t.references :changed_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.datetime :created_at, null: false
    end
    add_index :feature_flag_changes, %i[flag created_at]
  end
end
