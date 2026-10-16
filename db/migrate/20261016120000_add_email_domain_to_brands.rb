# The brand's e-mail domain in SES (spec 01, RN-01-040, D-596). Only new columns.
class AddEmailDomainToBrands < ActiveRecord::Migration[8.1]
  def change
    add_column :brands, :email_domain, :string
    add_column :brands, :email_domain_status, :string
    add_column :brands, :email_domain_records, :jsonb, null: false, default: []
    add_column :brands, :email_domain_checked_at, :datetime
    add_column :brands, :email_domain_registered_by_id, :bigint
  end
end
