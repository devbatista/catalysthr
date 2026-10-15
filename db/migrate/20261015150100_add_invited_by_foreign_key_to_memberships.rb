# Foreign key added without validation and validated apart, so the table is not
# blocked (strong_migrations).
class AddInvitedByForeignKeyToMemberships < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :memberships, :users, column: :invited_by_id, validate: false
  end
end
