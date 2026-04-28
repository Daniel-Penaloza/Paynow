Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  # Super Admin
  namespace :admin do
    root "dashboard#index"
    resources :organizations do
      resources :users, shallow: true
    end
  end

  # Business Owner — zona autogestionable
  namespace :dashboard do
    root "overview#index"
    resources :businesses do
      resources :receipts, only: %i[index show]
      get :qr, on: :member
    end
  end

  # Pago público por subdominio — sin autenticación
  constraints subdomain: /.+/ do
    scope module: :public do
      get  "/:slug",        to: "payments#show", as: :pay
      post "/:slug/receipt", to: "payments#submit_receipt", as: :submit_receipt
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root "sessions#new"
end
