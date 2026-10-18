# The company's setting for allocation clients, off by default (RN-04-090, D-570), and
# the values of the custom fields in the person's record (RN-04-081, P-04-26).
class AddCustomFieldsAndAllocationClientsToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :uses_allocation_clients, :boolean, null: false, default: false
    add_column :worker_profiles, :custom_fields, :jsonb, null: false, default: {}
  end
end
