Rails.application.routes.draw do
  scope module: :reginald do
    namespace :av do
      resources :graphs, only: [:index, :create, :destroy]

      resources :shairport_sync, only: [:destroy]
      post "shairport_sync/:id" => "shairport_sync#create"
    end
  end
end
