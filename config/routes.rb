Rails.application.routes.draw do
  # Health check used by Railway and the uptime monitors (spec 20).
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"
end
