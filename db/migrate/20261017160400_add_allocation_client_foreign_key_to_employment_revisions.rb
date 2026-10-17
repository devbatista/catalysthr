# The foreign key of the revision's client, validated apart so the table is not locked
# (strong_migrations).
class AddAllocationClientForeignKeyToEmploymentRevisions < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :employment_revisions, :allocation_clients, validate: false
  end
end
