# The client where the employment is allocated, from the revision's date (RN-04-092,
# RN-04-093). Optional: none means the company's own team.
class AddAllocationClientToEmploymentRevisions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :employment_revisions, :allocation_client, index: { algorithm: :concurrently }
  end
end
