# Block 15d of spec 15 (D-655): the daily digest by e-mail (RN-15-040 to RN-15-044). SES gives
# one message id to the digest, so it stays here and not on each delivery. The delivery's
# reference has no foreign key, as the others of the table: the lines leave together
# (RN-15-090).
class CreateNotificationDigests < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    create_table :notification_digests, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :recipient_membership, type: :uuid, null: false, foreign_key: { to_table: :memberships }
      t.references :brand, type: :uuid, foreign_key: true
      t.uuid :notification_ids, array: true, null: false, default: []
      t.string :provider_message_id
      t.datetime :sent_at
      t.timestamps
      t.index :provider_message_id, unique: true, where: "provider_message_id IS NOT NULL"
      t.index :created_at
    end

    add_column :notification_deliveries, :digest_id, :uuid
    add_index :notification_deliveries, :digest_id, where: "digest_id IS NOT NULL", algorithm: :concurrently
  end
end
