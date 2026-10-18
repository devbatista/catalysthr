Rails.application.routes.draw do
  # Paths and route names are in English; only the interface is in Portuguese.

  # Health check used by Railway and the uptime monitors (spec 20). Answers on any host (D-573).
  get "up" => "rails/health#show", as: :rails_health_check

  # SES events through SNS (spec 15, P-15-24, D-609). Answers on any host, without sign-in;
  # the controller accepts only messages signed by SNS for the app's topic.
  post "webhooks/ses-events", to: "ses_events#create", as: :ses_events

  # Sign-in, recovery and unlock (spec 02), on the admin host and on every brand's
  # subdomain. Who may sign in depends on the host (RN-02-004, RN-01-002).
  devise_for :users, path: "", controllers: { sessions: "users/sessions" },
    path_names: { sign_in: "sign-in", sign_out: "sign-out", password: "password", unlock: "unlock" }

  # Second step of the sign-in, for who uses MFA (RN-02-042).
  devise_scope :user do
    get "sign-in/code", to: "users/sessions#second_factor", as: :user_second_factor
    post "sign-in/code", to: "users/sessions#verify_second_factor", as: nil
  end

  # The person's own security: password, MFA, recovery codes, remembered devices and
  # open sessions (RN-02-042, RN-02-043, RN-02-053).
  namespace :account, path: "security" do
    root "security#show"
    resource :password, only: %i[edit update]
    resource :mfa, only: %i[new create destroy], controller: "mfa"
    resource :recovery_codes, only: :create, path: "recovery-codes"
    resources :sessions, only: :destroy
    resources :trusted_devices, only: :destroy, path: "trusted-devices"
  end

  # HostResolver (spec 01, RN-01-001) tags each request with its area; unknown hosts
  # never reach the routes.
  constraints ->(request) { request.env[HostResolver::AREA] == :admin } do
    scope module: :admin, as: :admin do
      root "home#index"
      # The bell (spec 15, RN-15-001).
      resources :notifications, only: %i[index show] do
        get "unread-count", on: :collection, action: :unread_count, as: :unread_count
      end
      resources :legal_documents, only: %i[index new create], path: "legal-documents"
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
      # The notices' channels: the company's defaults and each person's (spec 15, RN-15-020, RN-15-021).
      resource :company_notification_settings, path: "settings/notifications", only: %i[edit update]
      resource :notification_preferences, path: "notification-preferences", only: %i[edit update]
      resources :units, except: :destroy
      resources :departments, except: :destroy
      resources :positions, except: :destroy
      # Custom fields and allocation clients (spec 04, RN-04-080 to RN-04-096, D-605).
      resources :custom_fields, path: "custom-fields", only: %i[index new create edit update]
      resources :allocation_clients, path: "clients", except: :destroy do
        member do
          patch :managers
          post :invite_manager, path: "invite-manager"
        end
      end
      # The people, their employments and revisions (spec 04, RN-04-040 to RN-04-064).
      resources :employees, except: :destroy do
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
      # The official CBO, searched by code or title for the position's form (RN-04-031).
      get "cbo-search", to: "cbo_searches#index", as: :cbo_search
      # Address by CEP and the unit's position, for the unit's form (D-215, D-216).
      get "address-lookup/:postal_code", to: "address_lookups#show", as: :address_lookup
      get "geocode", to: "address_lookups#geocode", as: :geocode

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
        get "soon/:feature", to: "coming_soon#show", as: :coming_soon,
          constraints: { feature: Regexp.union(ComingSoon::PARTNER_FEATURES) }
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
        resources :companies, only: [] do
          resource :brand, only: %i[edit update], controller: "company_brands"
          resources :hr_admins, path: "hr-admins", controller: "company_hr_admins" do
            post :resend_invitation, path: "resend-invitation", on: :member
          end
        end
      end
    end
  end
end
