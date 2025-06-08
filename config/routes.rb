require 'sidekiq/web'
require 'sidekiq-scheduler/web'

Rails.application.routes.draw do
  # Authentication - disable registration for closed site
  devise_for :users, skip: [:registrations]

  # Admin interface
  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'

  # Opt-out functionality for resident notifications
  get '/opt-out/:token', to: 'opt_outs#show', as: :opt_out
  post '/opt-out/:token', to: 'opt_outs#create'

  namespace :api do
    resources :houses
    resources :residents
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root 'pages#map'

  # Mount Sidekiq web UI with authentication
  if Rails.env.development?
    mount Sidekiq::Web => '/sidekiq'
  else
    # In production, protect Sidekiq with authentication
    Sidekiq::Web.use(Rack::Auth::Basic) do |user, password|
      [user, password] == ['admin', ENV['SIDEKIQ_PASSWORD']]
    end
    mount Sidekiq::Web => '/sidekiq'
  end
end
