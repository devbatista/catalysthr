class ValidateSubscriptionsReactivatedByForeignKey < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :subscriptions, :users, column: :reactivated_by_id
  end
end
