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

ActiveRecord::Schema[8.1].define(version: 2026_10_19_150000) do
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

  create_table "accounting_firm_companies", force: :cascade do |t|
    t.bigint "accounting_firm_id", null: false
    t.bigint "company_id", null: false
    t.string "status", default: "pending", null: false
    t.bigint "linked_by_id"
    t.datetime "accepted_at"
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["accounting_firm_id"], name: "index_accounting_firm_companies_on_accounting_firm_id"
    t.index ["company_id", "status"], name: "index_accounting_firm_companies_on_company_id_and_status"
    t.index ["company_id"], name: "index_accounting_firm_companies_one_open_per_company", unique: true, where: "((status)::text = ANY ((ARRAY['pending'::character varying, 'active'::character varying])::text[]))"
    t.index ["linked_by_id"], name: "index_accounting_firm_companies_on_linked_by_id"
  end

  create_table "accounting_firms", force: :cascade do |t|
    t.string "name", null: false
    t.string "cnpj", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cnpj"], name: "index_accounting_firms_on_cnpj", unique: true
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

  create_table "add_on_prices", force: :cascade do |t|
    t.bigint "add_on_id", null: false
    t.integer "version", null: false
    t.date "valid_from", null: false
    t.integer "monthly_price_cents", null: false
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["add_on_id", "version"], name: "index_add_on_prices_on_add_on_id_and_version", unique: true
    t.index ["created_by_id"], name: "index_add_on_prices_on_created_by_id"
  end

  create_table "add_ons", force: :cascade do |t|
    t.string "code", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_add_ons_on_code", unique: true
  end

  create_table "allocation_client_managers", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "allocation_client_id", null: false
    t.bigint "membership_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["allocation_client_id", "membership_id"], name: "idx_on_allocation_client_id_membership_id_74ea9def8f", unique: true
    t.index ["allocation_client_id"], name: "index_allocation_client_managers_on_allocation_client_id"
    t.index ["company_id"], name: "index_allocation_client_managers_on_company_id"
    t.index ["membership_id"], name: "index_allocation_client_managers_on_membership_id"
  end

  create_table "allocation_clients", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.string "document_type"
    t.string "document"
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "document"], name: "index_allocation_clients_on_company_id_and_document", unique: true, where: "(document IS NOT NULL)"
    t.index ["company_id"], name: "index_allocation_clients_on_company_id"
  end

  create_table "bank_accounts", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "worker_profile_id", null: false
    t.string "bank_code"
    t.string "branch"
    t.text "account_number"
    t.string "account_type"
    t.string "pix_key_type"
    t.text "pix_key"
    t.boolean "primary", default: false, null: false
    t.string "status", default: "active", null: false
    t.date "ended_on"
    t.bigint "declared_by_id", null: false
    t.datetime "declared_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_bank_accounts_on_company_id"
    t.index ["declared_by_id"], name: "index_bank_accounts_on_declared_by_id"
    t.index ["worker_profile_id"], name: "index_bank_accounts_on_worker_profile_id"
    t.index ["worker_profile_id"], name: "index_bank_accounts_one_primary_per_profile", unique: true, where: "(\"primary\" AND ((status)::text = 'active'::text))"
  end

  create_table "billing_accounts", force: :cascade do |t|
    t.string "owner_type", null: false
    t.bigint "owner_id", null: false
    t.bigint "responsible_user_id"
    t.string "billing_email"
    t.integer "cycle_day", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id"], name: "index_billing_accounts_on_owner", unique: true
    t.index ["responsible_user_id"], name: "index_billing_accounts_on_responsible_user_id"
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
    t.string "email_domain"
    t.string "email_domain_status"
    t.jsonb "email_domain_records", default: [], null: false
    t.datetime "email_domain_checked_at"
    t.bigint "email_domain_registered_by_id"
    t.index ["email_domain"], name: "index_brands_on_email_domain", unique: true
    t.index ["email_domain_status"], name: "index_brands_on_email_domain_status"
    t.index ["owner_type", "owner_id"], name: "index_brands_on_owner", unique: true
  end

  create_table "cbo_occupations", force: :cascade do |t|
    t.string "code", limit: 6, null: false
    t.string "title", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_cbo_occupations_on_code", unique: true
  end

  create_table "companies", force: :cascade do |t|
    t.bigint "partner_id"
    t.string "name", null: false
    t.string "legal_name", null: false
    t.string "brand_display_mode"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "employer_type"
    t.string "document"
    t.integer "read_only_period_days", default: 365, null: false
    t.integer "next_registration_number", default: 1, null: false
    t.boolean "uses_allocation_clients", default: false, null: false
    t.index ["document"], name: "index_companies_on_document", unique: true
    t.index ["partner_id"], name: "index_companies_on_partner_id"
  end

  create_table "company_notification_settings", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "notification_type", null: false
    t.string "channels", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "notification_type"], name: "index_company_notification_settings_unique", unique: true
  end

  create_table "company_transfers", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "from_partner_id"
    t.bigint "to_partner_id"
    t.bigint "performed_by_id", null: false
    t.text "authorized_by_text", null: false
    t.datetime "performed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_company_transfers_on_company_id"
    t.index ["from_partner_id"], name: "index_company_transfers_on_from_partner_id"
    t.index ["performed_by_id"], name: "index_company_transfers_on_performed_by_id"
    t.index ["to_partner_id"], name: "index_company_transfers_on_to_partner_id"
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

  create_table "custom_field_definitions", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "key", null: false
    t.string "label", null: false
    t.string "field_type", null: false
    t.jsonb "options", default: [], null: false
    t.boolean "required", default: false, null: false
    t.boolean "visible_to_employee", default: false, null: false
    t.boolean "editable_by_employee", default: false, null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "key"], name: "index_custom_field_definitions_on_company_id_and_key", unique: true
    t.index ["company_id"], name: "index_custom_field_definitions_on_company_id"
  end

  create_table "department_managers", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "department_id", null: false
    t.bigint "membership_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_department_managers_on_company_id"
    t.index ["department_id", "membership_id"], name: "index_department_managers_on_department_id_and_membership_id", unique: true
    t.index ["department_id"], name: "index_department_managers_on_department_id"
    t.index ["membership_id"], name: "index_department_managers_on_membership_id"
  end

  create_table "departments", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "unit_id", null: false
    t.bigint "parent_id"
    t.string "name", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_departments_on_company_id"
    t.index ["parent_id"], name: "index_departments_on_parent_id"
    t.index ["unit_id"], name: "index_departments_on_unit_id"
  end

  create_table "dependents", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "worker_profile_id", null: false
    t.string "name", null: false
    t.text "cpf"
    t.date "birth_date", null: false
    t.string "sex"
    t.string "relationship_type", null: false
    t.boolean "irrf", default: false, null: false
    t.boolean "family_allowance", default: false, null: false
    t.boolean "incapable", default: false, null: false
    t.string "status", default: "active", null: false
    t.date "ended_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_dependents_on_company_id"
    t.index ["worker_profile_id"], name: "index_dependents_on_worker_profile_id"
  end

  create_table "emergency_contacts", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "worker_profile_id", null: false
    t.string "name", null: false
    t.string "relationship"
    t.string "phone", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_emergency_contacts_on_company_id"
    t.index ["worker_profile_id"], name: "index_emergency_contacts_on_worker_profile_id"
  end

  create_table "employment_revisions", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "employment_id", null: false
    t.date "effective_on", null: false
    t.bigint "position_id", null: false
    t.string "cbo_code", limit: 6, null: false
    t.text "salary_cents"
    t.string "salary_unit", null: false
    t.text "variable_salary_description"
    t.bigint "unit_id", null: false
    t.bigint "department_id"
    t.decimal "weekly_hours", precision: 4, scale: 2
    t.string "reason", null: false
    t.text "justification"
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "allocation_client_id"
    t.index ["allocation_client_id"], name: "index_employment_revisions_on_allocation_client_id"
    t.index ["company_id"], name: "index_employment_revisions_on_company_id"
    t.index ["created_by_id"], name: "index_employment_revisions_on_created_by_id"
    t.index ["department_id"], name: "index_employment_revisions_on_department_id"
    t.index ["employment_id", "effective_on", "id"], name: "idx_on_employment_id_effective_on_id_45d58acd76"
    t.index ["employment_id"], name: "index_employment_revisions_on_employment_id"
    t.index ["position_id"], name: "index_employment_revisions_on_position_id"
    t.index ["unit_id"], name: "index_employment_revisions_on_unit_id"
  end

  create_table "employments", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "worker_profile_id", null: false
    t.string "kind", null: false
    t.string "category"
    t.string "registration_number", null: false
    t.string "status", default: "active", null: false
    t.date "started_on", null: false
    t.date "ended_on"
    t.string "termination_reason"
    t.jsonb "details", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "registration_number"], name: "index_employments_on_company_id_and_registration_number", unique: true
    t.index ["company_id"], name: "index_employments_on_company_id"
    t.index ["worker_profile_id"], name: "index_employments_on_worker_profile_id"
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

  create_table "impersonation_sessions", force: :cascade do |t|
    t.bigint "impersonator_id", null: false
    t.bigint "impersonated_user_id", null: false
    t.bigint "brand_id", null: false
    t.text "reason", null: false
    t.string "token_digest"
    t.datetime "token_expires_at", null: false
    t.datetime "started_at"
    t.datetime "expires_at"
    t.datetime "ended_at"
    t.string "ended_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id"], name: "index_impersonation_sessions_on_brand_id"
    t.index ["impersonated_user_id"], name: "index_impersonation_sessions_on_impersonated_user_id"
    t.index ["impersonator_id"], name: "index_impersonation_sessions_on_impersonator_id"
    t.index ["token_digest"], name: "index_impersonation_sessions_on_token_digest", unique: true
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

  create_table "membership_units", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "membership_id", null: false
    t.bigint "unit_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_membership_units_on_company_id"
    t.index ["membership_id", "unit_id"], name: "index_membership_units_on_membership_id_and_unit_id", unique: true
    t.index ["membership_id"], name: "index_membership_units_on_membership_id"
    t.index ["unit_id"], name: "index_membership_units_on_unit_id"
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

  create_table "notification_deliveries", force: :cascade do |t|
    t.bigint "notification_id", null: false
    t.string "channel", null: false
    t.string "status", default: "queued", null: false
    t.integer "attempts", default: 0, null: false
    t.string "destination_masked"
    t.string "provider_message_id"
    t.string "failed_reason"
    t.datetime "sent_at"
    t.datetime "delivered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notification_id"], name: "index_notification_deliveries_on_notification_id"
    t.index ["provider_message_id"], name: "index_notification_deliveries_on_provider_message_id", unique: true, where: "(provider_message_id IS NOT NULL)"
  end

  create_table "notification_preferences", force: :cascade do |t|
    t.bigint "membership_id", null: false
    t.string "notification_type", null: false
    t.string "channels", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["membership_id", "notification_type"], name: "index_notification_preferences_unique", unique: true
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "company_id"
    t.bigint "recipient_user_id", null: false
    t.bigint "recipient_membership_id"
    t.bigint "brand_id"
    t.string "area"
    t.string "notification_type", null: false
    t.string "title", null: false
    t.text "body"
    t.string "path", null: false
    t.string "subject_type"
    t.bigint "subject_id"
    t.boolean "mandatory", default: false, null: false
    t.boolean "urgent", default: false, null: false
    t.boolean "in_bell", default: true, null: false
    t.string "dedup_key"
    t.datetime "read_at"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id"], name: "index_notifications_on_brand_id"
    t.index ["company_id"], name: "index_notifications_on_company_id"
    t.index ["created_at"], name: "index_notifications_on_created_at"
    t.index ["dedup_key", "created_at"], name: "index_notifications_on_dedup_key_and_created_at", where: "(dedup_key IS NOT NULL)"
    t.index ["recipient_membership_id"], name: "index_notifications_on_recipient_membership_id"
    t.index ["recipient_user_id", "created_at"], name: "index_notifications_bell", where: "(in_bell AND (archived_at IS NULL))"
    t.index ["recipient_user_id"], name: "index_notifications_on_recipient_user_id"
    t.index ["subject_type", "subject_id"], name: "index_notifications_on_subject"
  end

  create_table "partner_membership_companies", force: :cascade do |t|
    t.bigint "membership_id", null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_partner_membership_companies_on_company_id"
    t.index ["membership_id", "company_id"], name: "index_partner_membership_companies_on_membership_and_company", unique: true
  end

  create_table "partners", force: :cascade do |t|
    t.string "name", null: false
    t.string "legal_name", null: false
    t.string "cnpj", limit: 14, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cnpj"], name: "index_partners_on_cnpj", unique: true
  end

  create_table "plan_modules", force: :cascade do |t|
    t.bigint "plan_version_id", null: false
    t.string "module", null: false
    t.integer "price_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["plan_version_id", "module"], name: "index_plan_modules_on_plan_version_id_and_module", unique: true
  end

  create_table "plan_versions", force: :cascade do |t|
    t.bigint "plan_id", null: false
    t.integer "version", null: false
    t.date "valid_from", null: false
    t.bigint "created_by_id", null: false
    t.integer "monthly_price_cents"
    t.integer "employee_limit"
    t.integer "overage_per_employee_cents"
    t.integer "ai_credits"
    t.integer "whatsapp_messages"
    t.integer "price_per_employee_cents"
    t.integer "minimum_monthly_cents"
    t.integer "ai_credits_per_employee"
    t.integer "whatsapp_messages_per_employee"
    t.integer "ai_credit_overage_cents", null: false
    t.integer "whatsapp_overage_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_plan_versions_on_created_by_id"
    t.index ["plan_id", "version"], name: "index_plan_versions_on_plan_id_and_version", unique: true
  end

  create_table "plans", force: :cascade do |t|
    t.string "kind", null: false
    t.string "name", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "kind, lower((name)::text)", name: "index_plans_on_kind_and_name", unique: true
  end

  create_table "positions", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.string "cbo_code", limit: 6, null: false
    t.integer "salary_min_cents"
    t.integer "salary_max_cents"
    t.text "description"
    t.text "requirements"
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_positions_on_company_id"
  end

  create_table "pre_activation_prices", force: :cascade do |t|
    t.integer "version", null: false
    t.date "valid_from", null: false
    t.integer "monthly_price_cents", null: false
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_pre_activation_prices_on_created_by_id"
    t.index ["version"], name: "index_pre_activation_prices_on_version", unique: true
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

  create_table "subscription_items", force: :cascade do |t|
    t.bigint "subscription_id", null: false
    t.string "kind", null: false
    t.string "module"
    t.bigint "add_on_price_id"
    t.date "starts_on", null: false
    t.date "ends_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["add_on_price_id"], name: "index_subscription_items_on_add_on_price_id"
    t.index ["subscription_id"], name: "index_subscription_items_on_subscription_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "billing_account_id", null: false
    t.bigint "plan_version_id", null: false
    t.bigint "pre_activation_price_id"
    t.string "status", null: false
    t.date "started_on", null: false
    t.date "trial_ends_on"
    t.date "activated_on"
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["billing_account_id"], name: "index_subscriptions_on_billing_account_id", unique: true
    t.index ["created_by_id"], name: "index_subscriptions_on_created_by_id"
    t.index ["plan_version_id"], name: "index_subscriptions_on_plan_version_id"
    t.index ["pre_activation_price_id"], name: "index_subscriptions_on_pre_activation_price_id"
  end

  create_table "support_accesses", force: :cascade do |t|
    t.bigint "support_user_id", null: false
    t.bigint "company_id", null: false
    t.bigint "brand_id", null: false
    t.text "reason", null: false
    t.string "token_digest"
    t.datetime "token_expires_at", null: false
    t.datetime "started_at"
    t.datetime "ended_at"
    t.string "ended_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id"], name: "index_support_accesses_on_brand_id"
    t.index ["company_id"], name: "index_support_accesses_on_company_id"
    t.index ["support_user_id"], name: "index_support_accesses_on_support_user_id"
    t.index ["token_digest"], name: "index_support_accesses_on_token_digest", unique: true
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

  create_table "units", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.string "registration_type"
    t.string "registration_number"
    t.string "postal_code"
    t.string "street"
    t.string "street_number"
    t.string "complement"
    t.string "district"
    t.string "city"
    t.string "ibge_city_code"
    t.string "state"
    t.decimal "latitude", precision: 9, scale: 6
    t.decimal "longitude", precision: 9, scale: 6
    t.string "time_zone", default: "America/Sao_Paulo", null: false
    t.boolean "headquarters", default: false, null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_units_on_company_headquarters", unique: true, where: "headquarters"
    t.index ["company_id"], name: "index_units_on_company_id"
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
    t.string "email_status", default: "valid", null: false
    t.datetime "email_status_at"
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

  create_table "worker_profiles", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "membership_id", null: false
    t.string "social_name"
    t.string "sex"
    t.string "race"
    t.string "marital_status"
    t.string "education_level"
    t.string "birth_city"
    t.string "birth_state"
    t.string "birth_country"
    t.string "nationality"
    t.text "rg_number"
    t.string "rg_issuer"
    t.string "rg_state"
    t.date "rg_issued_on"
    t.text "ctps_number"
    t.string "ctps_series"
    t.string "ctps_state"
    t.text "pis_nis"
    t.text "voter_id"
    t.text "cnh_number"
    t.string "cnh_category"
    t.date "cnh_expires_on"
    t.text "class_registration"
    t.string "class_registration_issuer"
    t.text "foreign_registration"
    t.boolean "lives_abroad", default: false, null: false
    t.string "postal_code"
    t.string "street"
    t.string "street_number"
    t.string "complement"
    t.string "district"
    t.string "city"
    t.string "ibge_city_code"
    t.string "state"
    t.string "foreign_country"
    t.text "foreign_address"
    t.date "arrived_on"
    t.string "immigration_condition"
    t.boolean "married_to_brazilian"
    t.boolean "brazilian_children"
    t.text "disability"
    t.string "personal_phone"
    t.string "personal_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "custom_fields", default: {}, null: false
    t.index ["company_id"], name: "index_worker_profiles_on_company_id"
    t.index ["membership_id"], name: "index_worker_profiles_on_membership_id", unique: true
  end

  add_foreign_key "access_events", "companies"
  add_foreign_key "access_events", "users"
  add_foreign_key "access_events", "users", column: "impersonator_id"
  add_foreign_key "accounting_firm_companies", "accounting_firms"
  add_foreign_key "accounting_firm_companies", "companies"
  add_foreign_key "accounting_firm_companies", "users", column: "linked_by_id"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "add_on_prices", "add_ons"
  add_foreign_key "add_on_prices", "users", column: "created_by_id"
  add_foreign_key "allocation_client_managers", "allocation_clients", on_delete: :cascade
  add_foreign_key "allocation_client_managers", "companies"
  add_foreign_key "allocation_client_managers", "memberships", on_delete: :cascade
  add_foreign_key "allocation_clients", "companies"
  add_foreign_key "bank_accounts", "companies"
  add_foreign_key "bank_accounts", "users", column: "declared_by_id"
  add_foreign_key "bank_accounts", "worker_profiles"
  add_foreign_key "billing_accounts", "users", column: "responsible_user_id"
  add_foreign_key "brand_subdomains", "brands"
  add_foreign_key "brands", "users", column: "email_domain_registered_by_id", on_delete: :nullify
  add_foreign_key "companies", "partners"
  add_foreign_key "company_notification_settings", "companies"
  add_foreign_key "company_transfers", "companies"
  add_foreign_key "company_transfers", "partners", column: "from_partner_id"
  add_foreign_key "company_transfers", "partners", column: "to_partner_id"
  add_foreign_key "company_transfers", "users", column: "performed_by_id"
  add_foreign_key "consents", "legal_documents"
  add_foreign_key "consents", "users"
  add_foreign_key "custom_field_definitions", "companies"
  add_foreign_key "department_managers", "companies"
  add_foreign_key "department_managers", "departments", on_delete: :cascade
  add_foreign_key "department_managers", "memberships", on_delete: :cascade
  add_foreign_key "departments", "companies"
  add_foreign_key "departments", "departments", column: "parent_id"
  add_foreign_key "departments", "units"
  add_foreign_key "dependents", "companies"
  add_foreign_key "dependents", "worker_profiles"
  add_foreign_key "emergency_contacts", "companies"
  add_foreign_key "emergency_contacts", "worker_profiles"
  add_foreign_key "employment_revisions", "allocation_clients"
  add_foreign_key "employment_revisions", "companies"
  add_foreign_key "employment_revisions", "departments"
  add_foreign_key "employment_revisions", "employments"
  add_foreign_key "employment_revisions", "positions"
  add_foreign_key "employment_revisions", "units"
  add_foreign_key "employment_revisions", "users", column: "created_by_id"
  add_foreign_key "employments", "companies"
  add_foreign_key "employments", "worker_profiles"
  add_foreign_key "impersonation_sessions", "brands"
  add_foreign_key "impersonation_sessions", "users", column: "impersonated_user_id"
  add_foreign_key "impersonation_sessions", "users", column: "impersonator_id"
  add_foreign_key "legal_documents", "brands"
  add_foreign_key "legal_documents", "users", column: "published_by_id"
  add_foreign_key "membership_units", "companies"
  add_foreign_key "membership_units", "memberships", on_delete: :cascade
  add_foreign_key "membership_units", "units"
  add_foreign_key "memberships", "users"
  add_foreign_key "memberships", "users", column: "invited_by_id"
  add_foreign_key "notification_deliveries", "notifications"
  add_foreign_key "notification_preferences", "memberships"
  add_foreign_key "notifications", "brands"
  add_foreign_key "notifications", "companies"
  add_foreign_key "notifications", "memberships", column: "recipient_membership_id"
  add_foreign_key "notifications", "users", column: "recipient_user_id"
  add_foreign_key "partner_membership_companies", "companies"
  add_foreign_key "partner_membership_companies", "memberships"
  add_foreign_key "plan_modules", "plan_versions"
  add_foreign_key "plan_versions", "plans"
  add_foreign_key "plan_versions", "users", column: "created_by_id"
  add_foreign_key "positions", "companies"
  add_foreign_key "pre_activation_prices", "users", column: "created_by_id"
  add_foreign_key "subscription_items", "add_on_prices"
  add_foreign_key "subscription_items", "subscriptions"
  add_foreign_key "subscriptions", "billing_accounts"
  add_foreign_key "subscriptions", "plan_versions"
  add_foreign_key "subscriptions", "pre_activation_prices"
  add_foreign_key "subscriptions", "users", column: "created_by_id"
  add_foreign_key "support_accesses", "brands"
  add_foreign_key "support_accesses", "companies"
  add_foreign_key "support_accesses", "users", column: "support_user_id"
  add_foreign_key "trusted_devices", "users"
  add_foreign_key "units", "companies"
  add_foreign_key "user_sessions", "brands"
  add_foreign_key "user_sessions", "users"
  add_foreign_key "worker_profiles", "companies"
  add_foreign_key "worker_profiles", "memberships"
end
