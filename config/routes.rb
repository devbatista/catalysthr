Rails.application.routes.draw do
  # Health check used by Railway and the uptime monitors (spec 20). Answers on any host (D-573).
  get "up" => "rails/health#show", as: :rails_health_check

  # Sign-in, recovery and unlock (spec 02), on the admin host and on every brand's
  # subdomain. Who may sign in depends on the host (RN-02-004, RN-01-002).
  scope path_names: { new: "solicitar", edit: "redefinir" } do
    devise_for :users, path: "", path_names: {
      sign_in: "entrar", sign_out: "sair", password: "senha", unlock: "desbloqueio"
    }
  end

  # HostResolver (spec 01, RN-01-001) tags each request with its area; unknown hosts
  # never reach the routes.
  constraints ->(request) { request.env[HostResolver::AREA] == :admin } do
    scope module: :admin, as: :admin do
      root "home#index"
      resources :legal_documents, only: %i[index new create], path: "textos-legais", path_names: { new: "publicar" }
    end
  end

  constraints ->(request) { request.env[HostResolver::AREA] == :panel } do
    scope module: :panel do
      root "home#index"
      get "manifest.webmanifest", to: "manifests#show", as: :manifest

      # Invitation link and first access (RN-02-011, RN-02-014).
      get "convite", to: "invitations#show", as: :invitation
      patch "convite", to: "invitations#update"
      get "primeiro-acesso/termos", to: "legal_acceptances#show", as: :legal_acceptance
      post "primeiro-acesso/termos", to: "legal_acceptances#create"
    end
  end
end
