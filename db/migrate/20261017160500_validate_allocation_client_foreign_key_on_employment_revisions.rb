class ValidateAllocationClientForeignKeyOnEmploymentRevisions < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :employment_revisions, :allocation_clients
  end
end
