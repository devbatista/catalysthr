# A domain belongs to one brand only (D-596). The SES identity is shared by the whole
# account, so a second brand with the same domain could send on behalf of the first.
class IndexBrandsOnEmailDomain < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :brands, :email_domain, unique: true, algorithm: :concurrently
    add_index :brands, :email_domain_status, algorithm: :concurrently
    add_foreign_key :brands, :users, column: :email_domain_registered_by_id, on_delete: :nullify, validate: false
  end
end
