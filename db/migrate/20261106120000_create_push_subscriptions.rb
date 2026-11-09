# Block 15c of spec 15 (D-654): the push subscriptions (RN-15-004) and, on the deliveries,
# the hold of the quiet hours (RN-15-031), the fallback channel (RN-15-081) and the grouping
# on release (RN-15-034). The two references to the same table have no foreign key: the
# lines are deleted together with their notice (RN-15-090).
class CreatePushSubscriptions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    create_table :push_subscriptions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :brand, type: :uuid, null: false, foreign_key: true
      t.text :endpoint, null: false
      t.string :p256dh, null: false
      t.string :auth, null: false
      t.string :user_agent
      t.datetime :last_success_at
      t.timestamps
      t.index :endpoint, unique: true
    end

    add_column :notification_deliveries, :held_until, :datetime
    add_column :notification_deliveries, :fallback_from_id, :uuid
    add_column :notification_deliveries, :grouped_into_id, :uuid
    add_index :notification_deliveries, :held_until, where: "status = 'held'", algorithm: :concurrently
    add_index :notification_deliveries, :fallback_from_id, unique: true, where: "fallback_from_id IS NOT NULL",
      algorithm: :concurrently
    add_index :notification_deliveries, :grouped_into_id, where: "grouped_into_id IS NOT NULL", algorithm: :concurrently
  end
end
