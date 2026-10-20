# Validates the foreign key added without validation in CreateBillingAdjustments.
class ValidateInvoiceLinesBillingAdjustmentForeignKey < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :invoice_lines, :billing_adjustments
  end
end
