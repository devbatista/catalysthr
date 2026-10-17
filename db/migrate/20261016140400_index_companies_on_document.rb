# The employer's document is unique on the platform (RN-04-001, P-04-04).
class IndexCompaniesOnDocument < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :companies, :document, unique: true, algorithm: :concurrently
  end
end
