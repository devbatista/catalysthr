# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_15_013100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "brand_subdomains", force: :cascade do |t|
    t.bigint "brand_id", null: false
    t.string "slug", limit: 40, null: false
    t.string "status", default: "active", null: false
    t.datetime "redirect_until"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id"], name: "index_brand_subdomains_on_active_brand", unique: true, where: "((status)::text = 'active'::text)"
    t.index ["brand_id"], name: "index_brand_subdomains_on_brand_id"
    t.index ["redirect_until"], name: "index_brand_subdomains_on_redirect_until", where: "((status)::text = 'redirecting'::text)"
    t.index ["slug"], name: "index_brand_subdomains_on_slug_in_use", unique: true, where: "((status)::text <> 'released'::text)"
  end

  create_table "brands", force: :cascade do |t|
    t.string "owner_type", null: false
    t.bigint "owner_id", null: false
    t.string "commercial_name", null: false
    t.string "short_name"
    t.string "primary_color", limit: 7
    t.string "secondary_color", limit: 7
    t.string "accent_color", limit: 7
    t.text "login_welcome_text"
    t.string "support_email"
    t.string "support_phone"
    t.text "terms_text"
    t.text "privacy_policy_text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id"], name: "index_brands_on_owner", unique: true
  end

  create_table "companies", force: :cascade do |t|
    t.bigint "partner_id"
    t.string "name", null: false
    t.string "legal_name", null: false
    t.string "cnpj", limit: 14, null: false
    t.string "brand_display_mode"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cnpj"], name: "index_companies_on_cnpj", unique: true
    t.index ["partner_id"], name: "index_companies_on_partner_id"
  end

  create_table "flipper_features", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.string "feature_key", null: false
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "partners", force: :cascade do |t|
    t.string "name", null: false
    t.string "legal_name", null: false
    t.string "cnpj", limit: 14, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cnpj"], name: "index_partners_on_cnpj", unique: true
  end

  create_table "reserved_slugs", force: :cascade do |t|
    t.string "slug", limit: 40, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_reserved_slugs_on_slug", unique: true
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "brand_subdomains", "brands"
  add_foreign_key "companies", "partners"
end
