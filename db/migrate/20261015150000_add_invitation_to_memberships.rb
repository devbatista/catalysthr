# The invitation lives on the membership (spec 02, section 7; RN-02-010 to RN-02-012,
# P-02-37). Only the token's digest is stored.
class AddInvitationToMemberships < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :memberships, :invited_by, index: { algorithm: :concurrently }
    add_column :memberships, :invitation_token_digest, :string
    add_column :memberships, :invitation_sent_at, :datetime
    add_column :memberships, :invitation_expires_at, :datetime
    add_column :memberships, :invitation_channels, :string, array: true, null: false, default: []

    add_index :memberships, :invitation_token_digest, unique: true, algorithm: :concurrently
  end
end
