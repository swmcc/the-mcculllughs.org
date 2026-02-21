Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }

  # Root path - landing page for public, galleries for logged in
  root "home#index"

  # Galleries with nested uploads
  resources :galleries do
    resources :uploads, only: [ :create ]
  end

  # Uploads (for update/destroy actions outside nested route)
  resources :uploads, only: [ :update, :destroy ]

  # Public photo sharing (no auth required)
  get "t/:short_code", to: "public_photos#thumbnail", as: :public_thumbnail
  get "p/:short_code", to: "public_photos#show", as: :public_photo
  patch "p/:short_code", to: "public_photos#update"

  # Admin namespace
  namespace :admin do
    root "dashboard#index"
    resources :users
    resources :galleries
    resources :uploads
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
