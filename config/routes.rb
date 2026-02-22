Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }

  # Root path - landing page for public, galleries for logged in
  root "home#index"

  # Static pages
  get "about", to: "pages#about"
  get "colophon", to: "pages#colophon"

  # Search
  get "search", to: "search#index"

  # Spotify search API
  get "spotify/search", to: "spotify#search"

  # Galleries with nested uploads
  resources :galleries do
    resources :uploads, only: [ :create ]
  end

  # Uploads (for update/destroy actions outside nested route)
  resources :uploads, only: [ :update, :destroy ] do
    member do
      patch :set_cover
    end
  end

  # Saved slideshows
  resources :slideshows, only: [ :index, :show, :create, :edit, :update, :destroy ]

  # External photo imports
  resources :imports, only: [ :index ] do
    collection do
      get "providers"
      get ":provider/setup", action: :setup, as: :setup
      get ":provider/connect", action: :connect, as: :connect
      get ":provider/callback", action: :callback, as: :callback
      delete ":provider/disconnect", action: :disconnect, as: :disconnect
      get ":provider/albums", action: :albums, as: :albums
      post ":provider/import", action: :import, as: :import
    end
    member do
      get "status"
    end
  end

  # Public photo sharing (no auth required)
  get "t/:short_code", to: "public_photos#thumbnail", as: :public_thumbnail
  get "p/:short_code", to: "public_photos#show", as: :public_photo
  patch "p/:short_code", to: "public_photos#update"

  # Public slideshow sharing (no auth required)
  get "s/:short_code", to: "public_slideshows#show", as: :public_slideshow

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
