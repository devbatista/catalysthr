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

ActiveRecord::Schema[8.1].define(version: 2026_10_15_200000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "access_events", force: :cascade do |t|
    t.bigint "company_id"
    t.bigint "user_id", null: false
    t.bigint "impersonator_id"
    t.string "kind", null: false
    t.string "action", null: false
    t.string "subject_type"
    t.bigint "subject_id"
    t.string "field"
    t.string "ip"
    t.string "user_agent"
    t.string "request_id"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["company_id", "created_at"], name: "index_access_events_on_company_id_and_created_at"
    t.index ["company_id"], name: "index_access_events_on_company_id"
    t.index ["impersonator_id"], name: "index_access_events_on_impersonator_id"
    t.index ["subject_type", "subject_id"], name: "index_access_events_on_subject"
    t.index ["user_id", "created_at"], name: "index_access_events_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_access_events_on_user_id"
  end

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

  create_table "consents", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "kind", null: false
    t.string "scope_type", null: false
    t.bigint "scope_id", null: false
    t.bigint "legal_document_id"
    t.integer "document_version", null: false
    t.boolean "granted", null: false
    t.string "ip"
    t.string "user_agent"
    t.datetime "decided_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["legal_document_id"], name: "index_consents_on_legal_document_id"
    t.index ["scope_type", "scope_id"], name: "index_consents_on_scope"
    t.index ["user_id"], name: "index_consents_on_user_id"
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

  create_table "legal_documents", force: :cascade do |t|
    t.bigint "brand_id"
    t.string "kind", null: false
    t.integer "version", null: false
    t.text "body", null: false
    t.datetime "published_at", null: false
    t.bigint "published_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id", "kind", "version"], name: "index_legal_documents_on_brand_kind_and_version", unique: true, nulls_not_distinct: true
    t.index ["brand_id"], name: "index_legal_documents_on_brand_id"
    t.index ["published_by_id"], name: "index_legal_documents_on_published_by_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "organization_type", null: false
    t.bigint "organization_id", null: false
    t.string "roles", default: [], null: false, array: true
    t.string "status", default: "invited", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "invited_by_id"
    t.string "invitation_token_digest"
    t.datetime "invitation_sent_at"
    t.datetime "invitation_expires_at"
    t.string "invitation_channels", default: [], null: false, array: true
    t.string "enabled_modules", default: [], null: false, array: true
    t.bigint "unit_ids", default: [], null: false, array: true
    t.index ["invitation_token_digest"], name: "index_memberships_on_invitation_token_digest", unique: true
    t.index ["invited_by_id"], name: "index_memberships_on_invited_by_id"
    t.index ["organization_type", "organization_id"], name: "index_memberships_on_organization"
    t.index ["user_id", "organization_type", "organization_id"], name: "index_memberships_on_user_and_organization", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
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

  create_table "trusted_devices", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token_digest", null: false
    t.string "user_agent"
    t.datetime "last_used_at"
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_trusted_devices_on_expires_at"
    t.index ["token_digest"], name: "index_trusted_devices_on_token_digest", unique: true
    t.index ["user_id"], name: "index_trusted_devices_on_user_id"
  end

  create_table "user_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token_digest", null: false
    t.string "area", null: false
    t.bigint "brand_id"
    t.string "user_agent"
    t.string "ip"
    t.datetime "last_seen_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.string "revoked_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id"], name: "index_user_sessions_on_brand_id"
    t.index ["expires_at"], name: "index_user_sessions_on_expires_at"
    t.index ["token_digest"], name: "index_user_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_user_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "cpf", null: false
    t.string "email"
    t.string "mobile_phone"
    t.date "birth_date"
    t.string "status", default: "active", null: false
    t.string "platform_role"
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "otp_secret"
    t.integer "consumed_timestep"
    t.boolean "otp_required_for_login", default: false, null: false
    t.string "otp_backup_codes", array: true
    t.index ["cpf"], name: "index_users_on_cpf", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["platform_role"], name: "index_users_on_platform_role", where: "(platform_role IS NOT NULL)"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.jsonb "object"
    t.jsonb "object_changes"
    t.string "sensitive_fields", default: [], null: false, array: true
    t.bigint "impersonator_id"
    t.bigint "company_id"
    t.string "ip"
    t.string "request_id"
    t.datetime "created_at", null: false
    t.index ["company_id"], name: "index_versions_on_company_id"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "access_events", "companies"
  add_foreign_key "access_events", "users"
  add_foreign_key "access_events", "users", column: "impersonator_id"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "brand_subdomains", "brands"
  add_foreign_key "companies", "partners"
  add_foreign_key "consents", "legal_documents"
  add_foreign_key "consents", "users"
  add_foreign_key "legal_documents", "brands"
  add_foreign_key "legal_documents", "users", column: "published_by_id"
  add_foreign_key "memberships", "users"
  add_foreign_key "memberships", "users", column: "invited_by_id"
  add_foreign_key "trusted_devices", "users"
  add_foreign_key "user_sessions", "brands"
  add_foreign_key "user_sessions", "users"
end
