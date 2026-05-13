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
    resource :subscription, only: %i[show]
    resources :businesses do
      resources :receipts, only: %i[index show] do
        post :reprocess, on: :member
      end
      resources :clients, only: %i[index]
      resources :incomes, only: %i[index]
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

  # Rutas alternativas para desarrollo — permiten probar la landing pública
  # sin subdomain (útil con ngrok o cualquier tunnel sin soporte de subdomains).
  # Solo disponibles en development; no se montan en producción.
  if Rails.env.development?
    scope "/dev/pay/:org_subdomain", module: :public do
      get  "/:slug",         to: "payments#show",           as: :dev_pay
      post "/:slug/receipt", to: "payments#submit_receipt", as: :dev_submit_receipt
    end
  end

  # Webhook de Twilio para comprobantes por WhatsApp
  namespace :webhooks do
    post "twilio", to: "twilio#receive"
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root "sessions#new"

  match "/404",  to: "errors#not_found", via: :all
  match "*path", to: "errors#not_found", via: :all
end
