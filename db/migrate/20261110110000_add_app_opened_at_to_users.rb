# Block 17c of spec 17 (D-657): when the person last opened the portal as the installed app,
# for the partner's adoption figures (RN-17-041). Only the date, without the device.
class AddAppOpenedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :app_opened_at, :datetime
  end
end
