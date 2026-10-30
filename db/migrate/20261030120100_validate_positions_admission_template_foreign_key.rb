# Validates the foreign key added without validation in CreateProcessTemplates.
class ValidatePositionsAdmissionTemplateForeignKey < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :positions, :process_templates, column: :admission_template_id
  end
end
