require "sidekiq/web"

Rails.application.routes.draw do
  # Paths and route names are in English; only the interface is in Portuguese.

  # Health check used by Railway and the uptime monitors (spec 20). Answers on any host (D-573).
  get "up" => "rails/health#show", as: :rails_health_check
  # The detailed one, with a token: database, Redis and the Sidekiq queues (RN-20-074, D-627).
  get "up/deep" => "health_checks#show", as: :deep_health_check

  # SES events through SNS (spec 15, P-15-24, D-609). Answers on any host, without sign-in;
  # the controller accepts only messages signed by SNS for the app's topic.
  post "webhooks/ses-events", to: "ses_events#create", as: :ses_events

  # Mercado Pago's notices (spec 19, RN-19-046, D-622). Answers on any host, without
  # sign-in; the controller accepts only a notice signed with the account's secret.
  post "webhooks/mercado-pago", to: "mercado_pago_webhooks#create", as: :mercado_pago_webhooks

  # Asaas's notices about the NFS-e (spec 19, RN-19-106, D-633). Answers on any host,
  # without sign-in; the controller accepts only a notice with the webhook's token.
  post "webhooks/asaas", to: "asaas_webhooks#create", as: :asaas_webhooks

  # Sign-in, recovery and unlock (spec 02), on the admin host and on every brand's
  # subdomain. Who may sign in depends on the host (RN-02-004, RN-01-002).
  devise_for :users, path: "", controllers: { sessions: "users/sessions" },
    path_names: { sign_in: "sign-in", sign_out: "sign-out", password: "password", unlock: "unlock" }

  # Second step of the sign-in, for who uses MFA (RN-02-042).
  devise_scope :user do
    get "sign-in/code", to: "users/sessions#second_factor", as: :user_second_factor
    post "sign-in/code", to: "users/sessions#verify_second_factor", as: nil
    # Signing in with a passkey (RN-16-071, D-426).
    post "sign-in/passkey/challenge", to: "users/passkey_sessions#challenge", as: :user_passkey_challenge
    post "sign-in/passkey", to: "users/passkey_sessions#create", as: :user_passkey
  end

  # The person's own security: password, MFA, recovery codes, passkeys, remembered devices
  # and open sessions (RN-02-042, RN-02-043, RN-02-053, RN-16-070).
  namespace :account, path: "security" do
    root "security#show"
    resource :password, only: %i[edit update]
    resource :mfa, only: %i[new create destroy], controller: "mfa"
    resource :recovery_codes, only: :create, path: "recovery-codes"
    resources :sessions, only: :destroy
    resources :trusted_devices, only: :destroy, path: "trusted-devices"
    resources :passkeys, only: %i[create destroy] do
      post :challenge, on: :collection
    end
  end

  # HostResolver (spec 01, RN-01-001) tags each request with its area; unknown hosts
  # never reach the routes.
  constraints ->(request) { request.env[HostResolver::AREA] == :admin } do
    scope module: :admin, as: :admin do
      root "home#index"
      # Sidekiq Web, for the superadmin and the support with MFA (RN-20-077). Rack app:
      # the sign-in, the session checks and the ability come from Warden and Devise.
      authenticate :user, ->(user) { user.mfa_enabled? && PlatformAbility.new(user).can?(:read, :sidekiq_web) } do
        mount Sidekiq::Web => "/sidekiq", as: :sidekiq_web
      end
      # The bell (spec 15, RN-15-001).
      resources :notifications, only: %i[index show] do
        get "unread-count", on: :collection, action: :unread_count, as: :unread_count
      end
      resources :legal_documents, only: %i[index new create], path: "legal-documents"
      # The holidays: the national ones' review and the state and city ones (RN-11-020, D-638).
      resources :holidays, except: :show do
        member do
          patch :publish
          patch :reject
        end
        post :import, on: :collection
      end
      # The CatalystHR library of models of process (spec 06, D-126, D-639).
      resources :process_templates, path: "process-templates", except: :destroy do
        member do
          patch :activate
          patch :archive
          get "materials/:material_id", action: :material, as: :material
        end
        resources :items, controller: "process_template_items", except: %i[index show] do
          patch :move, on: :member
        end
      end
      # The platform's document types (spec 08, RN-08-001, D-642).
      resources :document_types, path: "document-types", except: %i[show destroy]
      # The feature flags (RN-20-030, D-617).
      resources :feature_flags, path: "feature-flags", param: :name, only: %i[index update destroy] do
        post :declare, on: :collection
      end
      resources :impersonations, only: %i[new create]
      # Brands (spec 01, section 6): partners' and direct companies', and the client
      # companies' own brands with their display mode.
      resources :brands, only: %i[index edit update] do
        patch :slug, on: :member
        resource :email_domain, only: %i[create destroy], path: "email-domain", controller: "brand_email_domains"
      end
      resources :companies, only: [] do
        resource :brand, only: %i[edit update], controller: "company_brands"
      end
      resources :support_accesses, only: %i[new create], path: "support-accesses"
      # Company transfer (RN-01-050 to RN-01-053, D-599).
      resources :company_transfers, only: %i[new create], path: "company-transfers"
      # Plans, modules and add-ons, with price versions (spec 19, RN-19-010 to RN-19-014, D-611).
      resources :plans, only: %i[index new create show edit update] do
        resources :versions, only: %i[new create], controller: "plan_versions"
      end
      resources :add_ons, only: [], path: "add-ons", param: :code do
        resources :prices, only: %i[new create], controller: "add_on_prices"
      end
      # The partner's pre-activation fee (RN-19-035, D-612).
      resources :pre_activation_prices, only: %i[new create], path: "pre-activation-prices"
      # The CatalystHR team's panel (RN-19-090, D-626).
      resource :dashboard, only: :show
      # Partners and direct companies with their contracts (RN-19-080, RN-19-081, D-613).
      resources :clients, only: %i[index new create show], controller: "billing_accounts" do
        # Changes to the contract by the team (RN-19-014, RN-19-060, RN-19-061, D-620).
        resource :contract, only: [], controller: "contract_changes" do
          patch :plan, action: :change_plan
          delete :plan, action: :cancel_scheduled
          post :price_migration, path: "price-migration", action: :migrate_price
          post "modules/:code", action: :add_module, as: :module
          delete "modules/:code", action: :remove_module
          post "add-ons/:code", action: :add_add_on, as: :add_on
          delete "add-ons/:code", action: :remove_add_on
          # The superadmin's reactivation of a contract in closing (RN-19-053, D-624).
          post :reactivation, action: :reactivate
          # The team undoes a cancellation the client asked, with the reason (RN-19-062, D-625).
          delete :cancellation, action: :undo_cancellation
        end
        # Manual adjustments of the next invoices (RN-19-070, D-621).
        resources :adjustments, only: %i[new create], controller: "billing_adjustments"
        # The contract's billing address, the NFS-e's customer at Asaas (RN-19-103, D-635).
        resource :billing_address, path: "billing-address", only: %i[edit update]
      end
      # Address by CEP, for the client's billing address (D-215, D-635).
      get "address-lookup/:postal_code", to: "address_lookups#show", as: :address_lookup
      # Adjustments waiting for the superadmin, and the latest ones (RN-19-071, D-621).
      resources :adjustments, only: :index, controller: "billing_adjustments" do
        member do
          post :approve
          post :cancel
        end
      end
      # The contracts' invoices (RN-19-040, RN-19-041, D-619).
      resources :invoices, only: %i[index show] do
        # Sending again a refused NFS-e (RN-19-108) and its PDF and XML (RN-19-107).
        post "service-invoice/reissue", to: "service_invoices#reissue", as: :reissue_service_invoice
        get "service-invoice/:kind", action: :service_invoice_file, on: :member, as: :service_invoice_file, kind: /pdf|xml/
      end
      # The NFS-e's fiscal settings (RN-19-102, D-633).
      resource :fiscal_settings, only: %i[show edit update], path: "fiscal-settings"
      resources :users, only: :index do
        member do
          patch :contact
          post :reset_mfa, path: "reset-mfa"
          post :release_email, path: "release-email"
        end
      end
    end
  end

  constraints ->(request) { request.env[HostResolver::AREA] == :panel } do
    scope module: :panel do
      root "home#index"
      get "manifest.webmanifest", to: "manifests#show", as: :manifest
      # The app's shell for the PWA and the page without connection (spec 16, RN-16-061,
      # RN-16-062, D-424).
      get "service-worker.js", to: "service_workers#show", as: :service_worker, format: false
      get "offline", to: "service_workers#offline", as: :offline
      # The bell (spec 15, RN-15-001).
      resources :notifications, only: %i[index show] do
        get "unread-count", on: :collection, action: :unread_count, as: :unread_count
      end
      # The brand's images (RN-01-014, RN-01-030).
      get "brand-assets/company/:kind", to: "brand_assets#company", as: :company_brand_asset
      get "brand-assets/:kind", to: "brand_assets#show", as: :brand_asset

      # The subdomain's side of the impersonate: the one-time link and ending it (RN-02-082,
      # RN-02-083).
      get "impersonation", to: "impersonations#show", as: :impersonation
      delete "impersonation", to: "impersonations#destroy", as: nil

      # The support's entry into a direct company (D-581).
      get "support-access", to: "support_accesses#show", as: :support_access
      delete "support-access", to: "support_accesses#destroy", as: nil

      # Invitation link and first access (RN-02-011, RN-02-014).
      get "invitation", to: "invitations#show", as: :invitation
      patch "invitation", to: "invitations#update", as: nil
      get "first-access/terms", to: "legal_acceptances#show", as: :legal_acceptance
      post "first-access/terms", to: "legal_acceptances#create", as: nil

      # Current company (RN-01-004, RN-01-005) and the company's users (spec 03, section 4.2).
      get "companies", to: "companies#index", as: :companies
      post "current-company", to: "companies#select", as: :current_company
      resources :memberships, path: "users" do
        member do
          post :resend_invitation, path: "resend-invitation"
          post :reset_mfa, path: "reset-mfa"
          patch :contact
        end
      end

      # The company's settings and units (spec 04, RN-04-002 to RN-04-014, D-601).
      resource :company_settings, path: "settings", only: %i[edit update]
      # The direct company's invoices (spec 19, RN-19-041, D-619) and its contracting during
      # the trial or after it (RN-19-033, D-622), with the NFS-e's PDF and XML (RN-19-107).
      resources :invoices, only: %i[index show] do
        get "service-invoice/:kind", action: :service_invoice_file, on: :member, as: :service_invoice_file, kind: /pdf|xml/
      end
      resource :contract, only: %i[new create]
      # The contract's billing address, the NFS-e's customer at Asaas (D-635).
      resource :billing_address, path: "contract/billing-address", only: %i[edit update]
      # The cancellation by the client and its undo (RN-19-062, D-625).
      resource :cancellation, path: "contract/cancellation", only: %i[show create destroy]
      # The notices' channels: the company's defaults and each person's (spec 15, RN-15-020, RN-15-021).
      resource :company_notification_settings, path: "settings/notifications", only: %i[edit update]
      resource :notification_preferences, path: "notification-preferences", only: %i[edit update]
      resources :units, except: :destroy do
        # The unit's holidays and optional days, and Good Friday turned off (RN-06-029, D-638).
        resources :holidays, only: %i[create destroy], controller: "unit_holidays"
      end
      resources :departments, except: :destroy
      resources :positions, except: :destroy
      # Custom fields and allocation clients (spec 04, RN-04-080 to RN-04-096, D-605).
      resources :custom_fields, path: "custom-fields", only: %i[index new create edit update]
      # The company's models of process (spec 06, D-240, D-639): adopting the partner's and the
      # library's (P-06-01) and the default of each kind (RN-06-003).
      resources :process_templates, path: "process-templates", except: :destroy do
        member do
          patch :activate
          patch :archive
          get "materials/:material_id", action: :material, as: :material
          patch :default
          patch "default-kinds", action: :default_kinds, as: :default_kinds
        end
        post :adopt, on: :collection
        resources :items, controller: "process_template_items", except: %i[index show] do
          patch :move, on: :member
        end
      end
      # The admissions (spec 07, D-648), with their contracts and terms (D-650).
      resources :admissions, only: %i[index new create show] do
        member do
          post :release
          patch :template, action: :change_template, as: :change_template
          patch "start-date", action: :reschedule, as: :reschedule
          patch :complete
          patch :cancel
          patch :reassess_aso, path: "reassess-aso"
        end
        resources :generated_documents, path: "contracts", only: %i[create show] do
          patch :signed, on: :member
        end
      end
      # The models of contracts and terms (RN-07-040, P-07-17).
      resources :document_templates, path: "document-templates", except: %i[show destroy] do
        get :preview, on: :member
      end
      # The processes under way (spec 06, RN-06-050 to RN-06-053, D-641): the generic page the
      # admission (spec 07) and the requests (spec 09) reuse. They start from those specs.
      resources :processes, only: :show do
        member do
          patch :complete
          patch :cancel
        end
        resources :items, controller: "process_items", only: %i[new create edit update destroy] do
          # The form item: fill, correct, give back and apply (RN-06-031, D-649).
          resource :form, controller: "process_forms", only: %i[edit update] do
            patch :apply
            patch "give-back", action: :give_back, as: :give_back
          end
          member do
            patch :move
            patch :done
            patch :approve
            patch :reject
            patch :forward
            patch :send_to_firm, path: "send-to-firm"
            patch :skip
            patch :reopen
            get :receipt
            get :material
          end
        end
      end
      resources :allocation_clients, path: "clients", except: :destroy do
        member do
          patch :managers
          post :invite_manager, path: "invite-manager"
        end
      end
      # The people, their employments and revisions (spec 04, RN-04-040 to RN-04-064).
      # The documents (spec 08, D-642): the review queue, each document with its versions and
      # the review, and the person's folder; the company's types and the platform's settings.
      resources :documents, only: %i[index show destroy] do
        # The documents expiring and expired in the HR's scope (RN-08-031, RN-08-032).
        get :expirations, on: :collection
        # The recovery within 30 days (RN-08-083, D-644).
        patch :restore, on: :member
        resources :versions, controller: "document_versions", only: %i[new create] do
          member do
            get :file
            patch :approve
            patch :correction
          end
        end
      end
      # The HR's requests (RN-08-040, D-278) and the publications asking for an acknowledgment,
      # with the refusal and the receipt (RN-08-050 to RN-08-054, D-279, D-643).
      resources :document_requests, path: "document-requests", only: %i[index new create show]
      resources :document_publications, path: "document-publications", only: %i[index new create show] do
        get :receipt, on: :member
        patch "acknowledgments/:acknowledgment_id/refuse", action: :refuse, on: :member, as: :refuse
      end
      # The HR's batches, confirmed by hand until spec 14 (RN-08-060 to RN-08-063, D-644), and
      # the folder's ZIP for who asked it (RN-08-082).
      resources :document_batches, path: "document-batches", only: %i[index create show] do
        member do
          post :files
          patch :items
          post :distribute
        end
      end
      resources :document_folder_exports, path: "document-exports", only: [] do
        get :download, on: :member
      end
      resources :document_types, path: "document-types", except: %i[show destroy] do
        patch :setting, on: :member
        resources :position_expirations, path: "position-expirations", controller: "position_document_expirations",
          only: %i[create destroy]
      end
      resources :employees, except: :destroy do
        # The portal's invitation of everyone without access, by e-mail (D-600, D-645).
        post :invite, on: :collection, action: :invite_all
        post :invite, on: :member
        resources :documents, controller: "employee_documents", only: %i[index new create]
        post "documents/export", to: "document_folder_exports#create", as: :document_export
        resources :employments, only: %i[new create]
        resources :emergency_contacts, path: "emergency-contacts", except: %i[index show]
        resources :dependents, except: %i[index show destroy] do
          patch "end", action: :close, on: :member, as: :end
        end
        resources :bank_accounts, path: "bank-accounts", only: %i[new create] do
          member do
            patch :primary, action: :make_primary
            patch "end", action: :close, as: :end
          end
        end
      end
      resources :employments, only: %i[edit update] do
        member do
          get :conversion
          post :conversion, action: :convert
        end
        resources :revisions, controller: "employment_revisions", only: %i[new create edit update destroy]
      end
      # The password before sensitive data (RN-02-052).
      get "confirm-password", to: "sensitive_confirmations#new", as: :new_sensitive_confirmation
      post "confirm-password", to: "sensitive_confirmations#create", as: :sensitive_confirmation
      post "confirm-password/passkey/challenge", to: "sensitive_passkey_confirmations#challenge", as: :sensitive_passkey_challenge
      post "confirm-password/passkey", to: "sensitive_passkey_confirmations#create", as: :sensitive_passkey_confirmation
      # The official CBO, searched by code or title for the position's form (RN-04-031).
      get "cbo-search", to: "cbo_searches#index", as: :cbo_search
      # Address by CEP and the unit's position, for the unit's form (D-215, D-216).
      get "address-lookup/:postal_code", to: "address_lookups#show", as: :address_lookup
      get "geocode", to: "address_lookups#geocode", as: :geocode

      # The employee's and the manager's portal (spec 16, RN-16-001, D-645): the start, the
      # folder with its uploads and acknowledgments, the process items, "Mais", the person's
      # data, "Minha equipe" and the bell.
      namespace :portal do
        root "home#index"
        resources :documents, only: %i[index show new create] do
          get :file, on: :member
          resources :versions, controller: "document_versions", only: %i[new create]
        end
        resources :acknowledgments, only: [] do
          patch :confirm, on: :member
        end
        resources :items, controller: "process_items", only: :show do
          member do
            patch :done
            patch :acknowledge
            patch :form
            get :material
          end
        end
        get "more", to: "more#show", as: :more
        get "my-data", to: "profiles#show", as: :profile
        get "team", to: "teams#show", as: :team
        resources :notifications, only: %i[index show]
      end

      # The prototype's modules not built yet (D-597).
      get "soon/:feature", to: "coming_soon#show", as: :coming_soon,
        constraints: { feature: Regexp.union(ComingSoon::COMPANY_FEATURES) }

      # The company's accounting firm (RN-02-070 to RN-02-073).
      resource :accounting_firm, path: "accounting-firm", only: %i[show new create destroy] do
        post :resend_invitation, path: "resend-invitation"
      end

      # The accounting firm's area: requests, linked companies and team (D-586, D-590).
      namespace :firm, module: :firm_panel do
        root "home#index"
        resources :links, only: [] do
          member do
            post :accept
            post :refuse
          end
        end
        # What the HR forwarded (RN-06-065, D-651, D-652).
        resources :forwards, only: %i[index show] do
          member do
            patch :confirm
            get "documents/:document_id", action: :document, as: :document
          end
        end
        resources :team_members, path: "team" do
          member do
            post :resend_invitation, path: "resend-invitation"
            post :reset_mfa, path: "reset-mfa"
          end
        end
      end

      # The partner's panel (spec 03, section 4.1): portfolio, team and the HR of the
      # client companies (D-584, D-585).
      namespace :partner, module: :partner_panel do
        root "home#index"
        # The partner's models of process, adopting the library's (spec 06, D-126, D-232, D-639).
        resources :process_templates, path: "process-templates", except: :destroy do
          member do
            patch :activate
            patch :archive
            get "materials/:material_id", action: :material, as: :material
          end
          post :adopt, on: :collection
          resources :items, controller: "process_template_items", except: %i[index show] do
            patch :move, on: :member
          end
        end
        resource :brand, only: %i[edit update] do
          resource :email_domain, only: %i[create destroy], path: "email-domain", controller: "brand_email_domains"
        end
        resources :team_members, path: "team" do
          member do
            post :resend_invitation, path: "resend-invitation"
            post :reset_mfa, path: "reset-mfa"
            patch :contact
          end
        end
        # The portfolio's usage and its CSV (spec 19, RN-19-024), the contract's invoices (D-619)
        # and the contracting during the trial or after it (RN-19-033, D-622).
        resource :usage, only: :show
        resources :invoices, only: %i[index show] do
          get "service-invoice/:kind", action: :service_invoice_file, on: :member, as: :service_invoice_file, kind: /pdf|xml/
        end
        resource :contract, only: %i[new create]
        # The contract's billing address, with the address by CEP (D-215, D-635).
        resource :billing_address, path: "contract/billing-address", only: %i[edit update]
        get "address-lookup/:postal_code", to: "address_lookups#show", as: :address_lookup
        # The cancellation by the client and its undo (RN-19-062, RN-19-063, D-625).
        resource :cancellation, path: "contract/cancellation", only: %i[show create destroy]
        resources :companies, only: %i[new create] do
          resource :brand, only: %i[edit update], controller: "company_brands"
          resource :modules, only: %i[edit update], controller: "company_modules"
          resources :hr_admins, path: "hr-admins", controller: "company_hr_admins" do
            post :resend_invitation, path: "resend-invitation", on: :member
          end
        end
      end
    end
  end
end
