# Brands and their subdomains (spec 01, section 7; P-01-01, P-01-11, P-01-15).
# E-mail domain and WhatsApp sender columns come with RN-01-040 and RN-01-041.
class CreateBrandsAndSubdomains < ActiveRecord::Migration[8.1]
  def change
    create_table :brands do |t|
      t.references :owner, polymorphic: true, null: false, index: { unique: true }
      t.string :commercial_name, null: false
      t.string :short_name
      t.string :primary_color, limit: 7
      t.string :secondary_color, limit: 7
      t.string :accent_color, limit: 7
      t.text :login_welcome_text
      t.string :support_email
      t.string :support_phone
      t.text :terms_text
      t.text :privacy_policy_text
      t.timestamps
    end

    create_table :brand_subdomains do |t|
      t.references :brand, null: false, foreign_key: true
      t.string :slug, null: false, limit: 40
      t.string :status, null: false, default: "active"
      t.datetime :redirect_until
      t.timestamps
    end
    # A slug stays taken while active or redirecting (RN-01-020, RN-01-022)
    add_index :brand_subdomains, :slug, unique: true, where: "status <> 'released'",
      name: "index_brand_subdomains_on_slug_in_use"
    add_index :brand_subdomains, :brand_id, unique: true, where: "status = 'active'",
      name: "index_brand_subdomains_on_active_brand"
    add_index :brand_subdomains, :redirect_until, where: "status = 'redirecting'"

    # Slugs the superadmin adds to the built-in reserved list (RN-01-021, P-01-11)
    create_table :reserved_slugs do |t|
      t.string :slug, null: false, limit: 40
      t.timestamps
    end
    add_index :reserved_slugs, :slug, unique: true
  end
end
