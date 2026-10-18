# The channels of each notice type (spec 15, RN-15-020 to RN-15-023, D-401): the company's
# defaults, set by the HR administrator, and each person's choice, per membership. The
# bell is always on and is not stored; only the external channels are.
class CreateNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :company_notification_settings do |t|
      t.references :company, null: false, foreign_key: true, index: false
      t.string :notification_type, null: false
      t.string :channels, array: true, null: false, default: []
      t.timestamps
    end
    add_index :company_notification_settings, %i[company_id notification_type], unique: true,
      name: "index_company_notification_settings_unique"

    create_table :notification_preferences do |t|
      t.references :membership, null: false, foreign_key: true, index: false
      t.string :notification_type, null: false
      t.string :channels, array: true, null: false, default: []
      t.timestamps
    end
    add_index :notification_preferences, %i[membership_id notification_type], unique: true,
      name: "index_notification_preferences_unique"
  end
end
