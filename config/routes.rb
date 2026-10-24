# frozen_string_literal: true

Rails.application.routes.draw do
  # NOTE: the root of the application is the user management table.
  root "users#index"

  # ----- authentication ------------------------------------------------------
  get    "/login",  to: "sessions#new",     as: :login
  post   "/login",  to: "sessions#create"
  delete "/logout", to: "sessions#destroy", as: :logout
  post   "/logout", to: "sessions#destroy"

  get  "/signup", to: "registrations#new",    as: :signup
  post "/signup", to: "registrations#create"

  # ----- the assistant (natural language) -------------------------------------
  get "/assistant", to: "assistant#index", as: :assistant

  # ----- the admin panel -----------------------------------------------------
  # IMPORTANT: there is NO route for a single user - the table works with a
  # selection of rows and the toolbar. There are no buttons inside the rows.
  resources :users, only: [:index]

  # NOTE: the three toolbar actions. They are collection routes, they always
  # work on a SELECTION of rows.
  post "/users/block_users",   to: "users#block_users",   as: :block_users
  post "/users/unblock_users", to: "users#unblock_users", as: :unblock_users
  post "/users/delete_users",  to: "users#delete_users",  as: :delete_users

  # ----- the JSON API --------------------------------------------------------
  namespace :api do
    namespace :v1 do
      resources :users, only: [:index] do
        collection do
          get  :stats
          post :bulk_block
          post :bulk_unblock
          post :bulk_delete
        end
      end

      post "assistant/ask",     to: "assistant#ask"
      post "assistant/command", to: "assistant#command"
    end
  end

  # NOTE: the health check of the deployment (used by the tunnel / monitoring).
  get "up" => "rails/health#show", as: :rails_health_check
end
