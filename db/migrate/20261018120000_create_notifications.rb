# Notices to a person (spec 15, section 7, D-607, D-608). A notice in the bell lives 90
# days; it and its deliveries are deleted after 1 year (RN-15-090). Not tenant-scoped,
# like memberships: a notice may come from a partner, an accounting firm or the
# platform, and every query names its recipient. The texts never carry sensitive data
# (RN-15-005).
class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :company, foreign_key: true
      t.references :recipient_user, null: false, foreign_key: { to_table: :users }
      t.references :recipient_membership, foreign_key: { to_table: :memberships }
      # The brand the e-mail goes out on behalf of and whose subdomain the link opens.
      t.references :brand, foreign_key: true
      # Where the notice shows: "panel", "admin" or both (null).
      t.string :area
      t.string :notification_type, null: false
      t.string :title, null: false
      t.text :body
      t.string :path, null: false
      t.references :subject, polymorphic: true
      t.boolean :mandatory, null: false, default: false
      t.boolean :urgent, null: false, default: false
      t.boolean :in_bell, null: false, default: true
      t.string :dedup_key
      t.datetime :read_at
      t.datetime :archived_at
      t.timestamps
    end

    add_index :notifications, %i[recipient_user_id created_at], where: "in_bell AND archived_at IS NULL",
      name: "index_notifications_bell"
    add_index :notifications, %i[dedup_key created_at], where: "dedup_key IS NOT NULL"
    add_index :notifications, :created_at
  end
end
