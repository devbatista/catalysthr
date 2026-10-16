class ValidateBrandsEmailDomainRegisteredByFk < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :brands, :users, column: :email_domain_registered_by_id
  end
end
