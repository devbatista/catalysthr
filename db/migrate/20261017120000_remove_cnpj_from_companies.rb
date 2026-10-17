# The full CNPJ lives in the headquarters unit and the employer is found by its document
# (RN-04-001, D-600). The column has been ignored since the previous release, so the
# running version no longer reads it.
class RemoveCnpjFromCompanies < ActiveRecord::Migration[8.1]
  def change
    safety_assured { remove_column :companies, :cnpj, :string, limit: 14 }
  end
end
