# The employer is identified by the CNPJ root or by the CPF (RN-04-001, D-200, D-600).
# The full CNPJ moves to the headquarters unit; the cnpj column stops being written and
# is removed in a later release.
class AddEmployerDocumentToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :employer_type, :string
    # Encrypted (deterministic): a CPF is personal data, and the root is searched.
    add_column :companies, :document, :string
    # Read-only period after the last termination, in days (D-090, D-423).
    add_column :companies, :read_only_period_days, :integer, null: false, default: 365
    change_column_null :companies, :cnpj, true
  end
end
