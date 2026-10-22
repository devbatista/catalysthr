class ValidateSubscriptionsCancellationForeignKeys < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :subscriptions, :users, column: :cancel_requested_by_id
    validate_foreign_key :subscriptions, :users, column: :cancel_undone_by_id
  end
end
