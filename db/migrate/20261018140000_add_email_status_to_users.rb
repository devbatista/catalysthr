# Whether the person's e-mail still receives (spec 15, RN-15-083, D-609): "valid",
# "bounced" (a permanent bounce: no e-mail at all) or "complained" (a spam complaint: no
# optional notices). Back to valid when the e-mail changes or the support releases it.
class AddEmailStatusToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :email_status, :string, null: false, default: "valid"
    add_column :users, :email_status_at, :datetime
  end
end
