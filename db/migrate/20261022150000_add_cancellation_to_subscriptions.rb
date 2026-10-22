# The cancellation asked by the client (spec 19, RN-19-062, RN-19-063, D-489, D-625): the
# last day of the paid cycle, when it takes effect, who asked, when and why; and the day the
# companies of a partner's portfolio were told; and the last undo, by the client or by the
# team, with the team's reason. The trail keeps the history.
class AddCancellationToSubscriptions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :subscriptions, :cancel_on, :date
    add_column :subscriptions, :cancel_requested_at, :datetime
    add_column :subscriptions, :cancel_reason, :string
    add_column :subscriptions, :cancel_reason_text, :text
    add_column :subscriptions, :cancel_portfolio_notified_on, :date
    add_column :subscriptions, :cancel_undone_at, :datetime
    add_column :subscriptions, :cancel_undone_reason, :text
    add_reference :subscriptions, :cancel_requested_by, type: :uuid, index: { algorithm: :concurrently }
    add_foreign_key :subscriptions, :users, column: :cancel_requested_by_id, validate: false
    add_reference :subscriptions, :cancel_undone_by, type: :uuid, index: { algorithm: :concurrently }
    add_foreign_key :subscriptions, :users, column: :cancel_undone_by_id, validate: false
  end
end
