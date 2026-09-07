Rails.application.routes.draw do
  get "login" => "sessions#new", as: :login
  post "login" => "sessions#create"
  delete "logout" => "sessions#destroy", as: :logout

  patch "locale" => "locales#update", as: :locale

  resource :account, only: %i[ show update ]

  namespace :admin do
    resources :users do
      member do
        patch :reset_password
      end
    end
    resources :announcements
    resources :admin_notes, only: %i[ index create destroy ]
  end

  resources :patients do
    resources :patient_diagnoses
  end
  resources :diagnoses
  resources :surgery_procedures
  resources :surgeries
  resources :hospitalizations do
    member do
      patch :confirm
      patch :restore
      post :copy
    end
    collection do
      get :deleted
    end
  end
  resources :elective_slot_rules
  resources :holidays
  resources :audit_events, only: %i[ index show ]
  get "surgery_schedule" => "surgery_schedules#index", as: :surgery_schedule
  get "operations_calendar" => "operations_calendar#index", as: :operations_calendar
  get "dashboard" => "dashboard#index"
  get "search" => "searches#index", as: :search
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "operations_calendar#index"
end
