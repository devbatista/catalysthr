# Validates the foreign keys added without validation in AddContractChanges.
class ValidateContractChangesForeignKeys < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :plans, :billing_accounts
    validate_foreign_key :subscriptions, column: :next_plan_version_id
    validate_foreign_key :invoice_lines, :prorations
  end
end
