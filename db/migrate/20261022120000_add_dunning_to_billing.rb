# The dunning of spec 19 (RN-19-050 to RN-19-053, D-624): the last step of the schedule
# each invoice has already gone through, so a day the job misses does not repeat or skip
# a notice; the day a contract went into closing, for the superadmin's 90 days; and the
# superadmin's reactivation, with its reason.
class AddDunningToBilling < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :invoices, :dunning_stage, :integer, null: false, default: 0
    add_column :subscriptions, :closing_on, :date
    add_column :subscriptions, :reactivated_at, :datetime
    add_column :subscriptions, :reactivation_reason, :text
    add_reference :subscriptions, :reactivated_by, type: :uuid, index: { algorithm: :concurrently }
    add_foreign_key :subscriptions, :users, column: :reactivated_by_id, validate: false
  end
end
