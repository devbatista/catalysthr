Rails.application.routes.draw do
  # Paths and route names are in English; only the interface is in Portuguese.

  # Health check used by Railway and the uptime monitors (spec 20). Answers on any host (D-573).
  get "up" => "rails/health#show", as: :rails_health_check

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
      resources :legal_documents, only: %i[index new create], path: "legal-documents"
    end
  end

  constraints ->(request) { request.env[HostResolver::AREA] == :panel } do
    scope module: :panel do
      root "home#index"
      get "manifest.webmanifest", to: "manifests#show", as: :manifest

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
        resources :team_members, path: "team" do
          member do
            post :resend_invitation, path: "resend-invitation"
            post :reset_mfa, path: "reset-mfa"
            patch :contact
          end
        end
        resources :companies, only: [] do
          resources :hr_admins, path: "hr-admins", controller: "company_hr_admins" do
            post :resend_invitation, path: "resend-invitation", on: :member
          end
        end
      end
    end
  end
end
