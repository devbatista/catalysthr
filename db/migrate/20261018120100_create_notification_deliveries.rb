# The sending of a notice through an external channel (spec 15, section 7). It keeps the
# channel, the masked destination and the statuses, never the message (RN-15-090). The
# phase 1 sends e-mail only; WhatsApp and push come in phase 2 (D-607).
class CreateNotificationDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_deliveries do |t|
      t.references :notification, null: false, foreign_key: true
      t.string :channel, null: false
      t.string :status, null: false, default: "queued"
      t.integer :attempts, null: false, default: 0
      t.string :destination_masked
      t.string :provider_message_id
      t.string :failed_reason
      t.datetime :sent_at
      t.datetime :delivered_at
      t.timestamps
    end

    add_index :notification_deliveries, :provider_message_id, unique: true, where: "provider_message_id IS NOT NULL"
  end
end
