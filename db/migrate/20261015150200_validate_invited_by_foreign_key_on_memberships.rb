class ValidateInvitedByForeignKeyOnMemberships < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :memberships, :users, column: :invited_by_id
  end
end
