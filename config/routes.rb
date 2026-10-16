Rails.application.routes.draw do
  get "login" => "sessions#new", as: :login
  post "login" => "sessions#create"
  delete "logout" => "sessions#destroy", as: :logout

  patch "locale" => "locales#update", as: :locale

  resource :account, only: %i[ show update ]

  namespace :admin do
    resources :users, only: %i[ index new create edit update ] do
      member do
        patch :reset_password
      end
    end
    resource :user_import, only: %i[ new create ] do
      get :template
    end
    resources :announcements, only: %i[ index new create edit update destroy ]
    resources :admin_notes, only: %i[ index create destroy ]
    resource :settings, only: %i[ edit update ], controller: "settings"
  end

  resources :patients do
    collection do
      get :picker
    end
    resources :patient_diagnoses
  end
  resources :diagnoses do
    collection do
      get :picker
    end
  end
  resources :surgery_procedures do
    collection do
      get :picker
    end
  end
  resources :surgeries do
    collection do
      get :patient_fields
      get :diagnosis_picker
    end
  end
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
  # The unified reservation (入約) form: a hospitalization and, for the purpose
  # surgery, its surgery on one screen. `:id` is the hospitalization's id. The
  # collection routes feed the form's live pieces (turbo-frames).
  resources :reservations, only: %i[ new create edit update ] do
    collection do
      get :patient_card
      get :admission_calendar
      get :admission_count
      get :slot_summary
      get :team_members
    end
  end
  resources :case_databases do
    resources :fields, controller: "case_database_fields", only: %i[ new create edit update destroy ]
    resources :entries, controller: "case_database_entries", only: %i[ new create edit update destroy ]
  end
  resources :elective_slot_rules
  resources :holidays
  resources :departments, :surgery_locations, :surgical_devices, except: :show
  resources :teams, except: :show do
    resources :team_terms, except: :show do
      post :copy_previous, on: :collection
    end
  end
  resources :audit_events, only: %i[ index show ]
  get "surgery_schedule" => "surgery_schedules#index", as: :surgery_schedule
  get "surgery_schedule/pdf" => "surgery_schedules#pdf", as: :surgery_schedule_pdf
  # The inline day-note editor of the operations calendar (admin only): `:date`
  # is the day's ISO date and the record is that day's Holiday row.
  resources :day_notes, only: %i[ show edit update destroy ], param: :date
  get "operations_calendar" => "operations_calendar#index", as: :operations_calendar
  # CSV exports of the configured `exports` (admin / data manager only); `:key`
  # is the export's name, `view` the screen it was started from.
  get "exports/:key" => "exports#show", as: :export, constraints: { key: /[a-z0-9_]+/ }
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
